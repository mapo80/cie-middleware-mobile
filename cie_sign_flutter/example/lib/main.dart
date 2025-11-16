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
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plugin = CieSignFlutter();
  String _status = 'Premi il pulsante per firmare il PDF di esempio.';
  String? _outputPath;
  bool _busy = false;
  String? _viewerError;

  Future<void> _runMockSign() async {
    setState(() {
      _busy = true;
      _status = 'Firma in corso...';
      _outputPath = null;
    });

    try {
      final data = await rootBundle.load('assets/sample.pdf');
      final bytes = data.buffer.asUint8List();
      final docsDir = await getApplicationDocumentsDirectory();
      final output = File('${docsDir.path}/mock_signed_flutter.pdf');
      final signed = await _plugin.mockSignPdf(
        bytes,
        outputPath: output.path,
      );
      await output.writeAsBytes(signed, flush: true);
      final header = String.fromCharCodes(signed.take(4));
      setState(() {
        _busy = false;
        _outputPath = output.path;
        _viewerError = null;
        _status = header.startsWith('%PDF')
            ? 'Firma completata (${signed.length} bytes).'
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
            if (_outputPath != null) Text('File salvato in\n$_outputPath'),
            _buildViewer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _runMockSign,
                child: Text(_busy ? 'In corso...' : 'Firma PDF di esempio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
