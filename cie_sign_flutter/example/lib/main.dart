import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hand_signature/signature.dart';
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

class _MyAppState extends State<MyApp> {
  final _plugin = CieSignFlutter();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final TextEditingController _pinController = TextEditingController(
    text: '25051980',
  );
  final HandSignatureControl _signatureControl = HandSignatureControl(
    initialSetup: const SignaturePathSetup(
      threshold: 3.0,
      smoothRatio: 0.65,
      velocityRange: 2.0,
      pressureRatio: 0.0,
    ),
  );

  String _status = 'Premi il pulsante per firmare il PDF di esempio.';
  String? _outputPath;
  bool _busy = false;
  Uint8List? _signatureImage;
  String? _viewerPath;
  StreamSubscription<NfcSessionEvent>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _nfcSubscription = _plugin.watchNfcEvents().listen(_handleNfcEvent);
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
    final data = await rootBundle.load('assets/sample.pdf');
    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _pinController.dispose();
    _signatureControl.dispose();
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

  Future<void> _saveSignatureFromPad() async {
    if (!_signatureControl.isFilled) {
      setState(() {
        _status = 'Disegna la tua firma prima di salvarla.';
      });
      return;
    }
    final byteData = await _signatureControl.toImage(
      width: 600,
      height: 200,
      format: ui.ImageByteFormat.png,
      background: Colors.transparent,
      color: Colors.black,
      fit: true,
    );
    if (byteData == null) {
      setState(() {
        _status = 'Impossibile convertire la firma. Riprova.';
      });
      return;
    }
    setState(() {
      _signatureImage = byteData.buffer.asUint8List();
      _persistSignatureImage(_signatureImage!);
      _status = 'Firma salvata. Ora puoi firmare il PDF.';
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

  void _clearSignaturePad() {
    _signatureControl.clear();
    setState(() {
      _signatureImage = null;
    });
  }

  Future<PdfSignatureAppearance> _buildAppearance() async {
    final image = await _resolveSignatureImage();
    return PdfSignatureAppearance(
      pageIndex: 0,
      left: 0.2,
      bottom: 0.65,
      width: 0.5,
      height: 0.2,
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
      await output.writeAsBytes(signed, flush: true);
      await _updateViewerPath(output.path);
      final header = String.fromCharCodes(signed.take(4));
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _status = header.startsWith('%PDF')
            ? 'Firma mock completata (${signed.length} bytes).'
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
      await output.writeAsBytes(signed, flush: true);
      await _updateViewerPath(output.path);
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _status = 'Firma con NFC completata (${signed.length} bytes).';
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
    return AnimatedBuilder(
      animation: _signatureControl,
      builder: (context, _) {
        final canSave = _signatureControl.isFilled;
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
                AspectRatio(
                  aspectRatio: 3,
                  child: DecoratedBox(
                    key: const Key('signaturePad'),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: HandSignature(
                      control: _signatureControl,
                      color: Colors.black,
                      width: 2,
                      maxWidth: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: !_busy && (canSave || hasSavedSignature)
                          ? _clearSignaturePad
                          : null,
                      child: const Text('Pulisci'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      key: const Key('saveSignatureButton'),
                      onPressed: (!_busy && canSave)
                          ? _saveSignatureFromPad
                          : null,
                      child: const Text('Salva firma'),
                    ),
                  ],
                ),
                if (hasSavedSignature) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Firma salvata (sarà applicata al PDF):',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 80,
                    child: Image.memory(_signatureImage!, fit: BoxFit.contain),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
