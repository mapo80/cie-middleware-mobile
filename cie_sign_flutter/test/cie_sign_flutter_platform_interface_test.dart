import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_platform_interface.dart';
import 'package:cie_sign_flutter/src/nfc_session_event.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MinimalPlatform extends CieSignFlutterPlatform {}

class _NoTokenPlatform extends PlatformInterface
    implements CieSignFlutterPlatform {
  _NoTokenPlatform() : super(token: Object());

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) => Future.value(pdfBytes);

  @override
  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) => Future.value(pdfBytes);

  @override
  Future<bool> cancelNfcSigning() => Future.value(false);

  @override
  Future<bool> verifyPinWithNfc({required String pin}) => Future.value(false);

  @override
  Stream<NfcSessionEvent> watchNfcEvents() =>
      const Stream<NfcSessionEvent>.empty();
}

class _FakePlatform extends CieSignFlutterPlatform {
  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) async {
    return pdfBytes;
  }

  @override
  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) async {
    return pdfBytes;
  }

  @override
  Future<bool> cancelNfcSigning() async => true;

  @override
  Future<bool> verifyPinWithNfc({required String pin}) async => true;

  @override
  Stream<NfcSessionEvent> watchNfcEvents() async* {}
}

void main() {
  test('base class throws for unimplemented methods', () async {
    final platform = _MinimalPlatform();
    await expectLater(
      () => platform.mockSignPdf(Uint8List(0)),
      throwsA(isA<UnimplementedError>()),
    );
    await expectLater(
      () => platform.signPdfWithNfc(Uint8List(0), pin: '12345678'),
      throwsA(isA<UnimplementedError>()),
    );
    await expectLater(
      () => platform.verifyPinWithNfc(pin: '12345678'),
      throwsA(isA<UnimplementedError>()),
    );
    await expectLater(
      () => platform.cancelNfcSigning(),
      throwsA(isA<UnimplementedError>()),
    );
    expect(() => platform.watchNfcEvents(), throwsA(isA<UnimplementedError>()));
  });

  test('instance setter enforces token', () {
    final original = CieSignFlutterPlatform.instance;
    CieSignFlutterPlatform.instance = _FakePlatform();
    expect(CieSignFlutterPlatform.instance, isA<_FakePlatform>());
    expect(() {
      CieSignFlutterPlatform.instance = _NoTokenPlatform();
    }, throwsA(isA<AssertionError>()));
    CieSignFlutterPlatform.instance = original;
  });
}
