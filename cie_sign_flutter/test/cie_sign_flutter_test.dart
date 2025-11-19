import 'dart:async';
import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_platform_interface.dart';
import 'package:cie_sign_flutter/src/nfc_session_event.dart';
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
  bool verifyCalled = false;
  final StreamController<NfcSessionEvent> controller =
      StreamController<NfcSessionEvent>.broadcast();

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

  @override
  Future<bool> verifyPinWithNfc({required String pin}) async {
    verifyCalled = true;
    return true;
  }

  @override
  Stream<NfcSessionEvent> watchNfcEvents() => controller.stream;

  void emitEvent(NfcSessionEvent event) {
    controller.add(event);
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
      pin: '25051980',
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

  test('verifyPinWithNfc proxies to platform', () async {
    final plugin = CieSignFlutter();
    final fakePlatform = MockCieSignFlutterPlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    final ok = await plugin.verifyPinWithNfc(pin: '25051980');
    expect(ok, isTrue);
    expect(fakePlatform.verifyCalled, isTrue);
  });

  test('watchNfcEvents exposes platform stream', () async {
    final plugin = CieSignFlutter();
    final fakePlatform = MockCieSignFlutterPlatform();
    CieSignFlutterPlatform.instance = fakePlatform;
    final events = <NfcSessionEvent>[];
    final sub = plugin.watchNfcEvents().listen(events.add);
    fakePlatform.emitEvent(
      NfcSessionEvent.fromMap({'type': 'state', 'status': 'ready'}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events, isNotEmpty);
    await sub.cancel();
  });

  test('mockSignPdf enforces non-empty input', () async {
    final plugin = CieSignFlutter();
    expect(() => plugin.mockSignPdf(Uint8List(0)), throwsArgumentError);
  });

  test('signPdfWithNfc validates inputs', () async {
    final plugin = CieSignFlutter();
    expect(
      () => plugin.signPdfWithNfc(Uint8List(0), pin: '25051980'),
      throwsArgumentError,
    );
    expect(
      () => plugin.signPdfWithNfc(Uint8List.fromList([1, 2, 3]), pin: ''),
      throwsArgumentError,
    );
  });

  test('verifyPinWithNfc validates pin', () async {
    final plugin = CieSignFlutter();
    expect(() => plugin.verifyPinWithNfc(pin: ''), throwsArgumentError);
  });
}
