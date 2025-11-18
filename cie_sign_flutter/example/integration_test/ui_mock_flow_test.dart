import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:cie_sign_flutter_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI mock flow signs PDF and embeds appearance', (WidgetTester tester) async {
    app.runCieSignApp(
      enablePdfView: false,
    );

    await tester.pumpAndSettle();

    final padFinder = find.byKey(const Key('signaturePad'));
    expect(padFinder, findsOneWidget);
    await tester.drag(padFinder, const Offset(120, 0));
    await tester.pump();
    await tester.drag(padFinder, const Offset(-80, -10));
    await tester.pump();

    final saveButton = find.byKey(const Key('saveSignatureButton'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final mockButton = find.byKey(const Key('mockSignButton'));
    expect(mockButton, findsOneWidget);
    await tester.tap(mockButton);

    bool previewShown = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.byKey(const Key('pdfFullScreenView')).evaluate().isNotEmpty) {
        previewShown = true;
        break;
      }
    }
    expect(previewShown, isTrue, reason: 'Preview did not appear');

    await tester.pageBack();
    await tester.pumpAndSettle();

    final outputWidget = tester.widget<SelectableText>(find.byKey(const Key('outputPathText')));
    final outputText = outputWidget.data ?? '';
    final lines = outputText.split('\n');
    final path = lines.length > 1 ? lines.last.trim() : '';
    expect(path.isNotEmpty, true);

    final bytes = await File(path).readAsBytes();
    final stats = await File(path).stat();
    debugPrint('Signed PDF generated at $path (created ${stats.changed.toIso8601String()})');
    final body = ascii.decode(bytes, allowInvalid: true);
    expect(body.contains('/Type/Sig'), true);
    expect(body.contains('/AP'), true);

    final downloadDir = Directory('/sdcard/Download');
    if (await downloadDir.exists()) {
      final externalPath = p.join(downloadDir.path, p.basename(path));
      try {
        await File(externalPath).writeAsBytes(bytes, flush: true);
        debugPrint('Copied signed PDF to $externalPath');
      } catch (_) {
        // ignore storage restrictions on emulators
      }
    }
  });
}
