import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfrx/pdfrx.dart';

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
      body: Stack(
        children: [
          Positioned.fill(
            child: KeyedSubtree(
              key: const Key('pdfFullScreenView'),
              child: PdfViewer.file(
                widget.path,
                key: ValueKey(widget.path),
                params: PdfViewerParams(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  loadingBannerBuilder: (context, downloaded, total) {
                    final progress = total != null && total > 0 ? downloaded / total : null;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (progress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${(progress * 100).toStringAsFixed(0)}%'),
                            ),
                        ],
                      ),
                    );
                  },
                  errorBannerBuilder: (context, error, stackTrace, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Errore viewer: $error',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_exporting)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
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
