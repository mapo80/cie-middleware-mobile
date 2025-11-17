import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.enablePdfView = true,
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
  final TextEditingController _pinController =
      TextEditingController(text: '12345678');

  String _status = 'Premi il pulsante per firmare il PDF di esempio.';
  String? _outputPath;
  bool _busy = false;
  String? _viewerError;
  Uint8List? _signatureImage;

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
    _pinController.dispose();
    super.dispose();
  }

  Future<Uint8List> _loadSignatureImage() async {
    if (_signatureImage != null) {
      return _signatureImage!;
    }
    final loader = widget.loadSignatureImage;
    if (loader != null) {
      _signatureImage = await loader();
      return _signatureImage!;
    }
    final data = await rootBundle.load('assets/signature.png');
    _signatureImage = data.buffer.asUint8List();
    return _signatureImage!;
  }

  Future<PdfSignatureAppearance> _buildAppearance() async {
    final image = await _loadSignatureImage();
    return PdfSignatureAppearance(
      pageIndex: 0,
      left: 0.1,
      bottom: 0.1,
      width: 0.4,
      height: 0.12,
      reason: 'Flutter demo',
      location: 'Mobile SDK',
      name: 'CIE Sign',
      fieldIds: const ['SignatureField1'],
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
      final docsDir = await getApplicationDocumentsDirectory();
      final output = File('${docsDir.path}/mock_signed_flutter.pdf');
      final signed = await _plugin.mockSignPdf(
        bytes,
        outputPath: output.path,
        appearance: appearance,
      );
      await output.writeAsBytes(signed, flush: true);
      final header = String.fromCharCodes(signed.take(4));
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _viewerError = null;
        _status = header.startsWith('%PDF')
            ? 'Firma mock completata (${signed.length} bytes).'
            : 'Output non riconosciuto.';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _status = 'Errore: $err';
        _viewerError = '$err';
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
      final docsDir = await getApplicationDocumentsDirectory();
      final output = File('${docsDir.path}/mock_signed_flutter_nfc.pdf');
      final appearance = await _buildAppearance();
      final signed = await _plugin.signPdfWithNfc(
        bytes,
        pin: pin,
        appearance: appearance,
        outputPath: output.path,
      );
      await output.writeAsBytes(signed, flush: true);
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _viewerError = null;
        _status = 'Firma con NFC completata (${signed.length} bytes).';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _status = 'Errore NFC: $err';
        _viewerError = '$err';
      });
    }
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
    if (_busy) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Firma del PDF in corso...'),
            ],
          ),
        ),
      );
    }

    final path = _outputPath;
    if (path == null) {
      return const Expanded(child: SizedBox.shrink());
    }

    if (!widget.enablePdfView) {
      return Expanded(
        child: Center(
          child: Text('PDF salvato in\n$path'),
        ),
      );
    }
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(top: 16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PDFView(
              key: ValueKey(path),
              filePath: path,
              autoSpacing: true,
              enableSwipe: true,
              swipeHorizontal: false,
              onError: (error) {
                setState(() {
                  _viewerError = error.toString();
                });
              },
              onRender: (_) {
                if (_viewerError != null) {
                  setState(() {
                    _viewerError = null;
                  });
                }
              },
            ),
            if (_viewerError != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text(
                    'Errore visualizzatore:\n$_viewerError',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CIE Sign Flutter Mock'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_status),
              const SizedBox(height: 12),
              TextField(
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
              if (_outputPath != null) ...[
                const SizedBox(height: 8),
                Text('File salvato in\n$_outputPath'),
              ],
              _buildViewer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _runMockSign,
                      child: Text(_busy ? 'In corso...' : 'Firma PDF (mock)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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
}
