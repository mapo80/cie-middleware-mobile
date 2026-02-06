import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'pdf_preview_page.dart';

// Enterprise color scheme - PDF red theme
class AppColors {
  static const Color primary = Color(0xFFE53935); // PDF Red
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color accent = Color(0xFF424242);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color divider = Color(0xFFEEEEEE);
}

void runCieSignApp({
  bool enablePdfView = true,
  Future<Uint8List> Function()? loadSamplePdf,
  Future<Uint8List> Function()? loadSignatureImage,
}) {
  runApp(
    MyApp(
      enablePdfView: enablePdfView,
      loadSamplePdf: loadSamplePdf,
      loadSignatureImage: loadSignatureImage,
    ),
  );
}

void main() {
  runCieSignApp();
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.enablePdfView,
    this.loadSamplePdf,
    this.loadSignatureImage,
  });

  final bool enablePdfView;
  final Future<Uint8List> Function()? loadSamplePdf;
  final Future<Uint8List> Function()? loadSignatureImage;

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Represents a sample PDF available for signing
class SamplePdfItem {
  final String name;
  final String assetPath;

  const SamplePdfItem({required this.name, required this.assetPath});
}

class _MyAppState extends State<MyApp> {
  final _plugin = CieSignFlutter();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final TextEditingController _pinController = TextEditingController(
    text: '25051980',
  );

  /// List of available sample PDFs
  static const List<SamplePdfItem> _availablePdfs = [
    SamplePdfItem(name: 'Sample.pdf', assetPath: 'assets/sample.pdf'),
    SamplePdfItem(
        name: 'Contratto Multi-pagina',
        assetPath: 'assets/multipage_contract.pdf'),
  ];

  String _status = 'Seleziona un documento e procedi con la firma.';
  String? _outputPath;
  bool _busy = false;
  Uint8List? _signatureImage;
  String? _viewerPath;
  StreamSubscription<NfcSessionEvent>? _nfcSubscription;

  /// Currently selected PDF
  SamplePdfItem _selectedPdf = _availablePdfs.first;

  /// Cached bytes of the selected PDF
  Uint8List? _selectedPdfBytes;

  /// Signature fields extracted from the selected PDF
  List<PdfSignatureFieldInfo> _signatureFields = [];

  /// Selected field IDs to sign (checkboxlist state)
  Set<String> _selectedFieldIds = {};

  /// Current signature type selection
  SignatureType _signatureType = SignatureType.manual;

  @override
  void initState() {
    super.initState();
    _nfcSubscription = _plugin.watchNfcEvents().listen(_handleNfcEvent);
    _loadSelectedPdfAndExtractFields();
  }

  /// Loads the selected PDF and extracts its signature fields
  Future<void> _loadSelectedPdfAndExtractFields() async {
    try {
      final bytes = await _loadPdfFromAsset(_selectedPdf.assetPath);
      _selectedPdfBytes = bytes;

      // Extract signature fields
      final fields = await _plugin.extractSignatureFields(bytes);

      if (mounted) {
        setState(() {
          _signatureFields = fields;
          // Pre-select unsigned fields
          _selectedFieldIds =
              fields.where((f) => !f.isSigned).map((f) => f.name).toSet();
          if (fields.isNotEmpty) {
            final unsigned = fields.where((f) => !f.isSigned).length;
            final signed = fields.length - unsigned;
            _status =
                '${fields.length} campi firma rilevati ($unsigned da firmare, $signed firmati)';
          } else {
            _status =
                'Nessun campo firma nel documento. La firma verra posizionata automaticamente.';
          }
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _signatureFields = [];
          _selectedFieldIds = {};
          _status = 'Errore nel caricamento: $err';
        });
      }
    }
  }

  /// Loads PDF bytes from the given asset path
  Future<Uint8List> _loadPdfFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  /// Called when the user selects a different PDF from the dropdown
  void _onPdfSelected(SamplePdfItem? pdf) {
    if (pdf == null || pdf == _selectedPdf) return;
    setState(() {
      _selectedPdf = pdf;
      _selectedPdfBytes = null;
      _signatureFields = [];
      _selectedFieldIds = {};
      _outputPath = null;
      _viewerPath = null;
    });
    _loadSelectedPdfAndExtractFields();
  }

  Future<File> _createOutputFile(String prefix) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${docsDir.path}/${prefix}_$timestamp.pdf');
  }

  Future<Uint8List> _loadSamplePdf() async {
    final loader = widget.loadSamplePdf;
    if (loader != null) {
      return loader();
    }
    // Use cached bytes if available
    if (_selectedPdfBytes != null) {
      return _selectedPdfBytes!;
    }
    return _loadPdfFromAsset(_selectedPdf.assetPath);
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _handleNfcEvent(NfcSessionEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case NfcSessionEventType.state:
        final status = event.status;
        String? message;
        if (status == 'not_supported') {
          message = 'NFC non supportato su questo dispositivo';
        } else if (status == 'disabled') {
          message = 'Attivare NFC per procedere';
        } else if (status == 'ready') {
          message = 'NFC pronto';
        }
        if (message != null) {
          setState(() => _status = message!);
        }
        break;
      case NfcSessionEventType.listening:
        setState(() => _status = 'In attesa della CIE...');
        break;
      case NfcSessionEventType.tag:
        setState(() => _status = 'Autenticazione in corso...');
        break;
      case NfcSessionEventType.completed:
        setState(() => _status = 'Operazione completata');
        break;
      case NfcSessionEventType.canceled:
        setState(() {
          _busy = false;
          _status = 'Operazione annullata';
        });
        break;
      case NfcSessionEventType.error:
        setState(() {
          _busy = false;
          _status = event.message ?? 'Errore NFC: ${event.code ?? 'sconosciuto'}';
        });
        break;
    }
  }

  Future<Uint8List> _resolveSignatureImage() async {
    final loader = widget.loadSignatureImage;
    if (loader != null) {
      return loader();
    }
    final cached = _signatureImage;
    if (cached != null) {
      return cached;
    }
    throw StateError(
      'Firma grafica non disponibile. Disegnare la firma o selezionare "Automatica".',
    );
  }

  void _onSignatureSaved(Uint8List pngBytes) {
    setState(() {
      _signatureImage = pngBytes;
      _status = 'Firma grafica acquisita';
    });
    _persistSignatureImage(pngBytes);
  }

  void _onSignatureCleared() {
    setState(() {
      _signatureImage = null;
    });
  }

  Future<void> _persistSignatureImage(Uint8List image) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final local = File('${docsDir.path}/last_signature.png');
      await local.writeAsBytes(image, flush: true);
    } catch (err) {
      debugPrint('Unable to persist last_signature.png: $err');
    }
  }

  Future<void> _updateViewerPath(String path) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final fileName = 'viewer_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final target = File('${cacheDir.path}/$fileName');
      await target.writeAsBytes(await File(path).readAsBytes(), flush: true);
      if (mounted) {
        setState(() => _viewerPath = target.path);
      } else {
        _viewerPath = target.path;
      }
    } catch (err) {
      debugPrint('Unable to copy viewer PDF: $err');
      _viewerPath = path;
    }
  }

  Future<PdfSignatureAppearance> _buildAppearance() async {
    Uint8List? image;
    bool useAutoSignature = false;

    if (_signatureType == SignatureType.manual) {
      image = await _resolveSignatureImage();
    } else if (_signatureType == SignatureType.automatic) {
      useAutoSignature = true;
    }

    if (_selectedFieldIds.isNotEmpty) {
      return PdfSignatureAppearance(
        reason: 'Firma digitale',
        location: 'CIE Sign SDK',
        name: 'CIE Sign',
        fieldIds: _selectedFieldIds.toList(),
        signatureImageBytes: image,
        useAutoSignature: useAutoSignature,
      );
    }

    return PdfSignatureAppearance(
      pageIndex: 0,
      left: 0.55,
      bottom: 0.05,
      width: 0.40,
      height: 0.10,
      reason: 'Firma digitale',
      location: 'CIE Sign SDK',
      name: 'CIE Sign',
      fieldIds: null,
      signatureImageBytes: image,
      useAutoSignature: useAutoSignature,
    );
  }

  Future<void> _runMockSign() async {
    setState(() {
      _busy = true;
      _status = 'Elaborazione in corso...';
      _outputPath = null;
    });

    try {
      final bytes = await _loadSamplePdf();
      final appearance = await _buildAppearance();
      final output = await _createOutputFile('mock_signed_flutter');
      final signed = await _plugin.mockSignPdf(
        bytes,
        outputPath: output.path,
        appearance: appearance,
      );
      await output.writeAsBytes(signed.bytes, flush: true);
      await _updateViewerPath(output.path);
      final header = String.fromCharCodes(signed.bytes.take(4));
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _status = header.startsWith('%PDF')
            ? 'Documento firmato (${signed.sizeInBytes} bytes)'
            : 'Errore: output non valido';
      });
      if (mounted) {
        await _showPdfPreview(output.path);
      }
    } on StateError catch (err) {
      setState(() {
        _busy = false;
        _status = err.message ?? 'Operazione non disponibile';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _status = 'Errore: $err';
      });
    }
  }

  Future<void> _runSignWithNfc() async {
    final pin = _pinController.text.trim();
    if (pin.length != 8) {
      setState(() => _status = 'Inserire PIN di 8 cifre');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Avvicinare la CIE al dispositivo...';
      _outputPath = null;
    });

    try {
      final bytes = await _loadSamplePdf();
      final output = await _createOutputFile('mock_signed_flutter_nfc');
      final appearance = await _buildAppearance();
      final signed = await _plugin.signPdfWithNfc(
        bytes,
        pin: pin,
        appearance: appearance,
        outputPath: output.path,
      );
      await output.writeAsBytes(signed.bytes, flush: true);
      await _updateViewerPath(output.path);
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _status = 'Firma completata (${signed.sizeInBytes} bytes)';
      });
      if (mounted) {
        await _showPdfPreview(output.path);
      }
    } on StateError catch (err) {
      setState(() {
        _busy = false;
        _status = err.message ?? 'Operazione non disponibile';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _status = 'Errore: $err';
      });
    }
  }

  Future<void> _runVerifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 8) {
      setState(() => _status = 'Inserire PIN di 8 cifre');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Verifica PIN in corso...';
    });

    try {
      final verified = await _plugin.verifyPinWithNfc(pin: pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = verified ? 'PIN verificato' : 'PIN non valido';
      });
      await _showPinResultDialog(
        verified,
        verified ? 'Verifica completata con successo.' : 'PIN non accettato.',
      );
    } on PlatformException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Errore: ${err.message ?? err.code}';
      });
      await _showPinResultDialog(false, 'Errore: ${err.message ?? err.code}');
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Errore: $err';
      });
      await _showPinResultDialog(false, 'Errore: $err');
    }
  }

  Future<void> _showPinResultDialog(bool success, String message) async {
    final ctx = _navigatorKey.currentContext ?? context;
    if (!mounted) return;
    await showDialog<void>(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            success ? 'Verifica Completata' : 'Verifica Fallita',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(message),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CHIUDI'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelNfcSigning() async {
    final canceled = await _plugin.cancelNfcSigning();
    if (canceled) {
      setState(() {
        _busy = false;
        _status = 'Operazione annullata';
      });
    }
  }

  Future<void> _previewSelectedPdf() async {
    if (_selectedPdfBytes == null) return;

    try {
      final cacheDir = await getTemporaryDirectory();
      final fileName = 'preview_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${cacheDir.path}/$fileName');
      await tempFile.writeAsBytes(_selectedPdfBytes!, flush: true);
      await _showPdfPreview(tempFile.path);
    } catch (err) {
      setState(() => _status = 'Errore anteprima: $err');
    }
  }

  void _toggleAllFields() {
    setState(() {
      final unsignedFields =
          _signatureFields.where((f) => !f.isSigned).map((f) => f.name).toSet();
      if (_selectedFieldIds.length == unsignedFields.length) {
        _selectedFieldIds.clear();
      } else {
        _selectedFieldIds = unsignedFields;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UI COMPONENTS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, IconData? icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfSelector() {
    return _buildSection(
      title: 'Documento',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SamplePdfItem>(
                      key: const Key('pdfDropdown'),
                      value: _selectedPdf,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      items: _availablePdfs.map((pdf) {
                        return DropdownMenuItem<SamplePdfItem>(
                          value: pdf,
                          child: Text(pdf.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _busy ? null : _onPdfSelected,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _busy || _selectedPdfBytes == null ? null : _previewSelectedPdf,
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Anteprima',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  disabledForegroundColor: AppColors.border,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureFieldsList() {
    if (_signatureFields.isEmpty) {
      return _buildSection(
        title: 'Campi Firma',
        icon: Icons.edit_document,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nessun campo firma nel documento.\nLa firma sara posizionata automaticamente.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final unsignedCount = _signatureFields.where((f) => !f.isSigned).length;

    return _buildSection(
      title: 'Campi Firma',
      icon: Icons.edit_document,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedFieldIds.length}/$unsignedCount selezionati',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _busy ? null : _toggleAllFields,
                child: Text(
                  _selectedFieldIds.length == unsignedCount
                      ? 'Deseleziona tutti'
                      : 'Seleziona tutti',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._signatureFields.map((field) => _buildFieldItem(field)),
        ],
      ),
    );
  }

  Widget _buildFieldItem(PdfSignatureFieldInfo field) {
    final isSelected = _selectedFieldIds.contains(field.name);
    final isDisabled = field.isSigned || _busy;

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                if (isSelected) {
                  _selectedFieldIds.remove(field.name);
                } else {
                  _selectedFieldIds.add(field.name);
                }
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.background,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: field.isSigned ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pag. ${field.pageIndex + 1}  |  ${field.width.toStringAsFixed(0)} x ${field.height.toStringAsFixed(0)} pt',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: field.isSigned
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
              ),
              child: Text(
                field.isSigned ? 'FIRMATO' : 'DA FIRMARE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: field.isSigned ? AppColors.success : AppColors.warning,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinSection() {
    return _buildSection(
      title: 'Autenticazione',
      icon: Icons.lock_outline,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('pinField'),
              controller: _pinController,
              maxLength: 8,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(fontSize: 14, letterSpacing: 2),
              decoration: InputDecoration(
                labelText: 'PIN CIE',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildOutlinedButton(
            onPressed: _busy ? null : _runVerifyPin,
            label: 'Verifica',
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureTypeSelector() {
    return _buildSection(
      title: 'Aspetto Firma',
      icon: Icons.brush_outlined,
      child: Column(
        children: [
          _buildRadioOption(
            value: SignatureType.manual,
            title: 'Firma manuale',
            subtitle: 'Disegna la tua firma',
          ),
          _buildRadioOption(
            value: SignatureType.automatic,
            title: 'Firma automatica',
            subtitle: 'Generata dal nominativo CIE',
          ),
          _buildRadioOption(
            value: SignatureType.none,
            title: 'Solo crittografica',
            subtitle: 'Nessun aspetto grafico',
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required SignatureType value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _signatureType == value;
    return InkWell(
      onTap: _busy ? null : () => setState(() => _signatureType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturePad() {
    final hasSavedSignature = _signatureImage != null;
    return _buildSection(
      title: 'Firma Grafica',
      icon: Icons.draw_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CieHandSignature(
            key: const Key('signaturePad'),
            signatureImage: _signatureImage,
            readOnly: true,
            config: const CieHandSignatureConfig(
              strokeColor: AppColors.textPrimary,
              backgroundColor: AppColors.background,
              minStrokeWidth: 2.0,
              maxStrokeWidth: 6.0,
              outputWidth: 600,
              outputHeight: 200,
            ),
            onSignatureSaved: _onSignatureSaved,
            showFullscreenButton: true,
            fullscreenOrientation: SignatureOrientation.landscape,
            fullscreenTitle: 'Firma',
            fullscreenSaveText: 'Salva',
            fullscreenCancelText: 'Annulla',
            emptyPlaceholder: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined, size: 28, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'Tocca per disegnare la firma',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (hasSavedSignature) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                const Text(
                  'Firma acquisita',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPrimaryButton(
                onPressed: _busy ? null : _runMockSign,
                label: _busy ? 'Elaborazione...' : 'FIRMA (TEST)',
                icon: Icons.edit_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrimaryButton(
                onPressed: _busy ? null : _runSignWithNfc,
                label: _busy ? 'Elaborazione...' : 'FIRMA NFC',
                icon: Icons.contactless_outlined,
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
              ),
              onPressed: _cancelNfcSigning,
              child: const Text('Annulla operazione'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOutputSection() {
    final path = _viewerPath ?? _outputPath;
    if (path == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              const Text(
                'Documento firmato',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOutlinedButton(
                  onPressed: () => _showPdfPreview(path),
                  icon: Icons.visibility_outlined,
                  label: 'Apri',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _outputPath!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Percorso copiato'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 20),
                tooltip: 'Copia percorso',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          else
            const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CIE Sign'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, size: 22),
              onPressed: () {},
              tooltip: 'Guida',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPdfSelector(),
                    _buildSignatureFieldsList(),
                    _buildPinSection(),
                    _buildSignatureTypeSelector(),
                    if (_signatureType == SignatureType.manual) _buildSignaturePad(),
                    _buildOutputSection(),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(String path) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute(builder: (_) => PdfPreviewPage(path: path)),
    );
  }
}
