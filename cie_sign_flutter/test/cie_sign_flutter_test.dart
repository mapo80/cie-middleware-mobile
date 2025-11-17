import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_platform_interface.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCieSignFlutterPlatform
    with MockPlatformInterfaceMixin
    implements CieSignFlutterPlatform {
  Uint8List? lastInput;
  String? lastPath;
  PdfSignatureAppearance? lastAppearance;
  bool signCalled = false;
  bool cancelCalled = false;

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) {
    lastInput = pdfBytes;
    lastPath = outputPath;
    lastAppearance = appearance;
    return Future.value(Uint8List.fromList(pdfBytes.reversed.toList()));
  }

  @override
  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) async {
    signCalled = true;
    return Uint8List.fromList(pdfBytes);
  }

  @override
  Future<bool> cancelNfcSigning() async {
    cancelCalled = true;
    return true;
  }
}

void main() {
  final CieSignFlutterPlatform initialPlatform =
      CieSignFlutterPlatform.instance;

  test('$MethodChannelCieSignFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCieSignFlutter>());
  });

  test('mockSignPdf forwards arguments', () async {
    final plugin = CieSignFlutter();
    final fakePlatform = MockCieSignFlutterPlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    final input = Uint8List.fromList([1, 2, 3, 4]);
    final result = await plugin.mockSignPdf(
      input,
      outputPath: '/tmp/result.pdf',
      appearance: const PdfSignatureAppearance(pageIndex: 1),
    );
    expect(fakePlatform.lastInput, equals(input));
    expect(fakePlatform.lastPath, '/tmp/result.pdf');
    expect(fakePlatform.lastAppearance?.pageIndex, 1);
    expect(result, equals(Uint8List.fromList([4, 3, 2, 1])));
  });

  test('signPdfWithNfc uses platform implementation', () async {
    final plugin = CieSignFlutter();
    final fakePlatform = MockCieSignFlutterPlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    final input = Uint8List.fromList([5, 6, 7]);
    final result = await plugin.signPdfWithNfc(
      input,
      pin: '12345678',
      appearance: const PdfSignatureAppearance(pageIndex: 2),
    );
    expect(result, equals(input));
    expect(fakePlatform.signCalled, isTrue);
  });

  test('cancelNfcSigning proxies to platform', () async {
    final plugin = CieSignFlutter();
    final fakePlatform = MockCieSignFlutterPlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    final canceled = await plugin.cancelNfcSigning();
    expect(canceled, isTrue);
    expect(fakePlatform.cancelCalled, isTrue);
  });
}
