import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_platform_interface.dart';
import 'package:cie_sign_flutter/src/nfc_session_event.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:cie_sign_flutter_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';
}

class _FakePlatform extends CieSignFlutterPlatform {
  bool nfcCalled = false;
  final StreamController<NfcSessionEvent> _controller =
      StreamController<NfcSessionEvent>.broadcast();

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) async {
    return Uint8List.fromList('%PDF'.codeUnits);
  }

  @override
  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) async {
    nfcCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Uint8List.fromList('%PDF'.codeUnits);
  }

  @override
  Future<bool> cancelNfcSigning() async => true;

  @override
  Future<bool> verifyPinWithNfc({required String pin}) async => true;

  @override
  Stream<NfcSessionEvent> watchNfcEvents() => _controller.stream;

  void emit(Map<String, dynamic> payload) {
    _controller.add(NfcSessionEvent.fromMap(payload));
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI shows NFC flow with mock platform', (tester) async {
    final fakePlatform = _FakePlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    PathProviderPlatform.instance = _FakePathProvider();

    await tester.pumpWidget(
      MyApp(
        enablePdfView: false,
        loadSamplePdf: () async => Uint8List.fromList('%PDF-TEST'.codeUnits),
        loadSignatureImage: () async =>
            Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
      ),
    );

    await tester.enterText(find.byKey(const Key('pinField')), '25051980');
    fakePlatform.emit({'type': 'state', 'status': 'ready'});
    await tester.tap(find.text('Firma con NFC'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(fakePlatform.nfcCalled, isTrue);
    final output = File('/tmp/mock_signed_flutter_nfc.pdf');
    expect(output.existsSync(), isTrue);
    fakePlatform.dispose();
  });
}
