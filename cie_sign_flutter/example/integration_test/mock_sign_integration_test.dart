import 'dart:io';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cie_sign_flutter_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mock signing produces a PDF with signature dictionary',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    final plugin = CieSignFlutter();
    final data = await rootBundle.load('assets/sample.pdf');
    final signature = await rootBundle.load('assets/signature.png');
    final appearance = PdfSignatureAppearance(
      pageIndex: 0,
      left: 0.1,
      bottom: 0.1,
      width: 0.4,
      height: 0.12,
      reason: 'Integration test',
      location: 'Mobile SDK',
      name: 'CIETest',
      fieldIds: const ['SignatureField1'],
      signatureImageBytes: signature.buffer.asUint8List(),
    );
    final docs = await getApplicationDocumentsDirectory();
    final output = File('${docs.path}/mock_signed_flutter_integration.pdf');
    final signed = await plugin.mockSignPdf(
      data.buffer.asUint8List(),
      outputPath: output.path,
      appearance: appearance,
    );
    expect(String.fromCharCodes(signed.take(4)), startsWith('%PDF'));
    expect(String.fromCharCodes(signed), contains('/Type/Sig'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), signed.length);
    final downloads = Directory('/sdcard/Download');
    if (await downloads.exists()) {
      try {
        final external = File('${downloads.path}/mock_signed_flutter.pdf');
        await external.writeAsBytes(signed, flush: true);
      } catch (_) {
        // scoped storage may deny direct access during integration tests
      }
    }
  });
}
