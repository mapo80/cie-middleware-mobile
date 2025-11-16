import 'dart:io';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mock signing produces a PDF with signature dictionary',
      (WidgetTester tester) async {
    final plugin = CieSignFlutter();
    final data = await rootBundle.load('assets/sample.pdf');
    final docs = await getApplicationDocumentsDirectory();
    final output = File('${docs.path}/mock_signed_flutter_integration.pdf');
    final signed = await plugin.mockSignPdf(
      data.buffer.asUint8List(),
      outputPath: output.path,
    );
    expect(String.fromCharCodes(signed.take(4)), startsWith('%PDF'));
    expect(String.fromCharCodes(signed), contains('/Type/Sig'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), signed.length);
  });
}
