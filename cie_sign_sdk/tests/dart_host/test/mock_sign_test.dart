import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:cie_sign_dart_host/cie_sign_host.dart';

void main() {
  final bridge = CieSignHostBridge.open();
  final packageRoot = Directory.current.absolute;
  final cieRoot = p.normalize(p.join(packageRoot.path, '../../'));
  final fixturesDir = p.join(cieRoot, 'data', 'fixtures');
  final pdfPath = p.join(fixturesDir, 'sample.pdf');
  final signaturePath = p.join(fixturesDir, 'signature.png');
  final outputDir = p.join(cieRoot, 'build', 'host');

  test('mock signing via FFI embeds appearance', () {
    final pdfBytes = File(pdfPath).readAsBytesSync();
    final signature = File(signaturePath).readAsBytesSync();
    Directory(outputDir).createSync(recursive: true);
    final signed = bridge.mockSignPdf(
      pdfBytes: pdfBytes,
      signatureImage: signature,
      fieldIds: const ['SignatureField1'],
    );

    final outputPath = p.join(outputDir, 'dart_mock_signed.pdf');
    File(outputPath).writeAsBytesSync(signed);

    final header = ascii.decode(signed.sublist(0, 4));
    expect(header, startsWith('%PDF'));

    final body = latin1.decode(signed, allowInvalid: true);
    expect(body.contains('/Type/Sig'), isTrue);
    expect(body.contains('/AP'), isTrue,
        reason: 'Signed PDF missing /AP appearance dictionary');
  });
}
