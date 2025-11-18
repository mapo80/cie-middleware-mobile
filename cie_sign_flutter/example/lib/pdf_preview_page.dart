import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class PdfPreviewPage extends StatefulWidget {
  const PdfPreviewPage({super.key, required this.path});

  final String path;

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.split('/').last),
        actions: [
          IconButton(
            key: const Key('sharePdfButton'),
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([XFile(widget.path)]),
          ),
          IconButton(
            key: const Key('savePdfButton'),
            icon: const Icon(Icons.download),
            onPressed: _exportToHost,
          ),
          IconButton(
            key: const Key('openExternalButton'),
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternal,
            tooltip: 'Apri con browser/visualizzatore',
          ),
        ],
      ),
      body: PDFView(
        key: const Key('pdfFullScreenView'),
        filePath: widget.path,
        enableSwipe: true,
        swipeHorizontal: false,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore viewer: $error')),
          );
        },
        onPageError: (page, error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore pagina $page: $error')),
          );
        },
      ),
    );
  }

  Future<void> _exportToHost() async {
    setState(() {
      _exporting = true;
    });
    try {
      final downloads = await getDownloadsDirectory();
      final targetDir = downloads ?? await getApplicationDocumentsDirectory();
      final fileName = p.basename(widget.path);
      final destination = File(p.join(targetDir.path, fileName));
      await destination.writeAsBytes(await File(widget.path).readAsBytes(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvato in ${destination.path}')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $err')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _openExternal() async {
    final result = await OpenFilex.open(widget.path, type: 'application/pdf');
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il PDF: ${result.message}')),
      );
    }
  }
}
