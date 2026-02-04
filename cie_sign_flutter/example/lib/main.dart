import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'pdf_preview_page.dart';

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
  ];

  String _status = 'Premi il pulsante per firmare il PDF di esempio.';
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
          _selectedFieldIds = fields
              .where((f) => !f.isSigned)
              .map((f) => f.name)
              .toSet();
          if (fields.isNotEmpty) {
            final unsigned = fields.where((f) => !f.isSigned).length;
            final signed = fields.length - unsigned;
            _status =
                'PDF caricato: ${fields.length} campi firma trovati ($unsigned da firmare, $signed firmati).';
          } else {
            _status =
                'PDF caricato: nessun campo firma trovato. La firma sarà posizionata in basso a destra dell\'ultima pagina.';
          }
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _signatureFields = [];
          _selectedFieldIds = {};
          _status = 'Errore nel caricamento del PDF: $err';
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
          message = 'NFC non supportato su questo dispositivo.';
        } else if (status == 'disabled') {
          message = 'Attiva l\'NFC per procedere con la firma.';
        } else if (status == 'ready') {
          message = 'NFC pronto. Premi “Firma con NFC” per iniziare.';
        }
        if (message != null) {
          final text = message;
          setState(() {
            _status = text;
          });
        }
        break;
      case NfcSessionEventType.listening:
        setState(() {
          _status = 'In ascolto... avvicina la CIE al lettore.';
        });
        break;
      case NfcSessionEventType.tag:
        setState(() {
          _status = 'Carta rilevata, autenticazione in corso...';
        });
        break;
      case NfcSessionEventType.completed:
        setState(() {
          _status = 'Sessione NFC completata.';
        });
        break;
      case NfcSessionEventType.canceled:
        setState(() {
          _busy = false;
          _status = 'Sessione NFC annullata.';
        });
        break;
      case NfcSessionEventType.error:
        setState(() {
          _busy = false;
          _status =
              event.message ?? 'Errore NFC: ${event.code ?? 'sconosciuto'}';
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
      'Per procedere devi prima disegnare e salvare la tua firma.',
    );
  }

  void _onSignatureSaved(Uint8List pngBytes) {
    setState(() {
      _signatureImage = pngBytes;
      _status = 'Firma salvata. Ora puoi firmare il PDF.';
    });
    _persistSignatureImage(pngBytes);
  }

  void _onSignatureCleared() {
    setState(() {
      _signatureImage = null;
    });
  }

  Future<void> _openFullscreenSignature() async {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;

    final bytes = await CieHandSignature.openFullscreen(
      navContext,
      initialImage: _signatureImage,
      config: const CieHandSignatureConfig(
        strokeColor: Colors.black,
        outputWidth: 600,
        outputHeight: 200,
      ),
      orientation: SignatureOrientation.landscape,
      title: 'Firma qui',
      saveButtonText: 'Salva',
      cancelButtonText: 'Annulla',
    );

    if (bytes != null && bytes.isNotEmpty && mounted) {
      _onSignatureSaved(bytes);
    } else if (bytes != null && bytes.isEmpty && mounted) {
      // User cleared the signature and saved
      _onSignatureCleared();
    }
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
        setState(() {
          _viewerPath = target.path;
        });
      } else {
        _viewerPath = target.path;
      }
    } catch (err) {
      debugPrint('Unable to copy viewer PDF: $err');
      _viewerPath = path;
    }
  }


  Future<PdfSignatureAppearance> _buildAppearance() async {
    final image = await _resolveSignatureImage();

    // If user selected specific fields, use them
    if (_selectedFieldIds.isNotEmpty) {
      return PdfSignatureAppearance(
        reason: 'Flutter demo',
        location: 'Mobile SDK',
        name: 'CIE Sign',
        fieldIds: _selectedFieldIds.toList(),
        signatureImageBytes: image,
      );
    }

    // No fields selected: sign at bottom-right of last page
    // pageIndex: 0 with no fieldIds defaults to last page in the SDK
    return PdfSignatureAppearance(
      pageIndex: 0, // Will use last page when no fieldIds specified
      left: 0.55, // 55% from left (toward right)
      bottom: 0.05, // 5% from bottom (near margin)
      width: 0.40, // 40% width
      height: 0.10, // 10% height
      reason: 'Flutter demo',
      location: 'Mobile SDK',
      name: 'CIE Sign',
      fieldIds: null,
      signatureImageBytes: image,
    );
  }

  Future<void> _runMockSign() async {
    setState(() {
      _busy = true;
      _status = 'Firma mock in corso...';
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
            ? 'Firma mock completata (${signed.sizeInBytes} bytes).'
            : 'Output non riconosciuto.';
      });
      if (mounted) {
        await _showPdfPreview(output.path);
      }
    } on StateError catch (err) {
      setState(() {
        _busy = false;
        _status = err.message ?? 'Firma non disponibile.';
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
      setState(() {
        _status = 'Inserisci un PIN di 8 cifre.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Avvicina la CIE al lettore NFC...';
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
        _status = 'Firma con NFC completata (${signed.sizeInBytes} bytes).';
      });
      if (mounted) {
        await _showPdfPreview(output.path);
      }
    } on StateError catch (err) {
      setState(() {
        _busy = false;
        _status = err.message ?? 'Firma non disponibile.';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _status = 'Errore NFC: $err';
      });
    }
  }

  Future<void> _runVerifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 8) {
      setState(() {
        _status = 'Inserisci un PIN di 8 cifre.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Avvicina la CIE al lettore per verificare il PIN...';
    });

    try {
      final verified = await _plugin.verifyPinWithNfc(pin: pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = verified
            ? 'PIN verificato correttamente.'
            : 'Verifica PIN non riuscita.';
      });
      await _showPinResultDialog(
        verified,
        verified
            ? 'La verifica del PIN è andata a buon fine.'
            : 'Il PIN inserito non è stato accettato.',
      );
    } on PlatformException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Verifica PIN fallita: ${err.message ?? err.code}.';
      });
      await _showPinResultDialog(
        false,
        'Verifica PIN fallita: ${err.message ?? err.code}.',
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Verifica PIN fallita: $err';
      });
      await _showPinResultDialog(
        false,
        'Verifica PIN fallita: $err',
      );
    }
  }

  Future<void> _showPinResultDialog(bool success, String message) async {
    final ctx = _navigatorKey.currentContext ?? context;
    if (!mounted || ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          title: Text(success ? 'Verifica PIN riuscita' : 'Verifica PIN fallita'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
        _status = 'Sessione NFC annullata.';
      });
    }
  }

  /// Builds the PDF selector dropdown with preview button
  Widget _buildPdfSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documento PDF',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SamplePdfItem>(
                    key: const Key('pdfDropdown'),
                    value: _selectedPdf,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _availablePdfs.map((pdf) {
                      return DropdownMenuItem<SamplePdfItem>(
                        value: pdf,
                        child: Text(pdf.name),
                      );
                    }).toList(),
                    onChanged: _busy ? null : _onPdfSelected,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: const Key('previewPdfButton'),
                  onPressed: _busy || _selectedPdfBytes == null
                      ? null
                      : _previewSelectedPdf,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Anteprima'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows preview of the currently selected (unsigned) PDF
  Future<void> _previewSelectedPdf() async {
    if (_selectedPdfBytes == null) return;

    try {
      // Write the PDF to a temp file for preview
      final cacheDir = await getTemporaryDirectory();
      final fileName = 'preview_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${cacheDir.path}/$fileName');
      await tempFile.writeAsBytes(_selectedPdfBytes!, flush: true);
      await _showPdfPreview(tempFile.path);
    } catch (err) {
      setState(() {
        _status = 'Errore nell\'anteprima: $err';
      });
    }
  }

  /// Builds the signature fields checkboxlist
  Widget _buildSignatureFieldsList() {
    if (_signatureFields.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campi Firma',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nessun campo firma trovato nel PDF.\n'
                        'La firma sarà posizionata in basso a destra dell\'ultima pagina.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Campi Firma',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _busy ? null : _toggleAllFields,
                  child: Text(
                    _selectedFieldIds.length ==
                            _signatureFields.where((f) => !f.isSigned).length
                        ? 'Deseleziona tutti'
                        : 'Seleziona tutti',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedFieldIds.length} campo/i selezionato/i',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ..._signatureFields.map((field) => _buildFieldCheckbox(field)),
          ],
        ),
      ),
    );
  }

  /// Builds a single checkbox item for a signature field
  Widget _buildFieldCheckbox(PdfSignatureFieldInfo field) {
    final isSelected = _selectedFieldIds.contains(field.name);
    final isDisabled = field.isSigned || _busy;

    return CheckboxListTile(
      key: Key('fieldCheckbox_${field.name}'),
      value: isSelected,
      onChanged: isDisabled
          ? null
          : (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedFieldIds.add(field.name);
                } else {
                  _selectedFieldIds.remove(field.name);
                }
              });
            },
      title: Text(
        field.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: field.isSigned ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        'Pagina ${field.pageIndex + 1} • '
        '${field.width.toStringAsFixed(0)}×${field.height.toStringAsFixed(0)} pt • '
        '${field.isSigned ? "Già firmato" : "Da firmare"}',
        style: TextStyle(
          fontSize: 12,
          color: field.isSigned ? Colors.grey : Colors.grey.shade600,
        ),
      ),
      secondary: Icon(
        field.isSigned ? Icons.check_circle : Icons.edit_note,
        color: field.isSigned ? Colors.green : Colors.orange,
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  /// Toggles selection of all unsigned fields
  void _toggleAllFields() {
    setState(() {
      final unsignedFields =
          _signatureFields.where((f) => !f.isSigned).map((f) => f.name).toSet();
      if (_selectedFieldIds.length == unsignedFields.length) {
        // All selected -> deselect all
        _selectedFieldIds.clear();
      } else {
        // Not all selected -> select all unsigned
        _selectedFieldIds = unsignedFields;
      }
    });
  }

  Widget _buildViewer() {
    final path = _viewerPath ?? _outputPath;
    if (path == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ElevatedButton.icon(
          key: const Key('openViewerButton'),
          onPressed: () => _showPdfPreview(path),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Apri il PDF firmato'),
        ),
      ),
    );
  }

  Widget _buildSignaturePad() {
    final hasSavedSignature = _signatureImage != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firma con il dito',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CieHandSignature(
              key: const Key('signaturePad'),
              signatureImage: _signatureImage,
              readOnly: true,
              config: const CieHandSignatureConfig(
                strokeColor: Colors.black,
                backgroundColor: Color(0xFFF5F5F5),
                minStrokeWidth: 2.0,
                maxStrokeWidth: 6.0,
                outputWidth: 600,
                outputHeight: 200,
              ),
              onSignatureSaved: _onSignatureSaved,
              showFullscreenButton: true,
              fullscreenOrientation: SignatureOrientation.landscape,
              fullscreenTitle: 'Firma qui',
              fullscreenSaveText: 'Salva',
              fullscreenCancelText: 'Annulla',
              emptyPlaceholder: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.draw_outlined, size: 32, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Tocca per creare la firma',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            if (hasSavedSignature) ...[
              const SizedBox(height: 8),
              const Text(
                'Firma salvata (sarà applicata al PDF)',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('CIE Sign Flutter Mock')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_status, key: const Key('statusText')),
              const SizedBox(height: 12),
              if (_busy) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
              ],
              // PDF Selector dropdown with preview button
              _buildPdfSelector(),
              // Signature fields checkboxlist
              _buildSignatureFieldsList(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('pinField'),
                      controller: _pinController,
                      maxLength: 8,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN (8 cifre)',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    key: const Key('verifyPinButton'),
                    onPressed: _busy ? null : _runVerifyPin,
                    child: const Text('Verifica PIN'),
                  ),
                ],
              ),
              if (_outputPath != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        'File salvato in\n$_outputPath',
                        key: const Key('outputPathText'),
                      ),
                    ),
                    IconButton(
                      key: const Key('copyPathButton'),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copia percorso',
                      onPressed: () {
                        final path = _outputPath!;
                        Clipboard.setData(ClipboardData(text: path));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Percorso copiato')),
                        );
                      },
                    ),
                  ],
                ),
              ],
              _buildSignaturePad(),
              _buildViewer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('mockSignButton'),
                      onPressed: _busy ? null : _runMockSign,
                      child: Text(_busy ? 'In corso...' : 'Firma PDF (mock)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('nfcSignButton'),
                      onPressed: _busy ? null : _runSignWithNfc,
                      child: Text(_busy ? 'In corso...' : 'Firma con NFC'),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? _cancelNfcSigning : null,
                  child: const Text('Annulla NFC'),
                ),
              ),
            ],
          ),
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
