import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full stack mock sign adds appearance stream', (WidgetTester tester) async {
    final plugin = CieSignFlutter();
    final pdfData = await rootBundle.load('assets/sample.pdf');
    final signature = await rootBundle.load('assets/signature.png');
    final appearance = PdfSignatureAppearance(
      pageIndex: 0,
      left: 0.1,
      bottom: 0.1,
      width: 0.4,
      height: 0.12,
      reason: 'Integration mock',
      location: 'Full stack',
      name: 'SDK',
      fieldIds: const ['SignatureField1'],
      signatureImageBytes: signature.buffer.asUint8List(),
    );

    final signed = await plugin.mockSignPdf(
      pdfData.buffer.asUint8List(),
      appearance: appearance,
    );

    final text = ascii.decode(signed, allowInvalid: true);
    expect(text.contains('/Type/Sig'), isTrue);
    expect(text.contains('/AP'), isTrue, reason: 'Signed PDF missing appearance dictionary');

    final downloadDir = Directory('/sdcard/Download');
    if (await downloadDir.exists()) {
      try {
        await File('${downloadDir.path}/mock_signed_fullstack.pdf').writeAsBytes(signed, flush: true);
      } catch (_) {
        // scoped storage può bloccare la scrittura durante i test; ignoriamo l'errore
      }
    }
  });
}
