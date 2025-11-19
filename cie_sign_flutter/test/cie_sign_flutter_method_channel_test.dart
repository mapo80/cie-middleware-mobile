import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/src/nfc_session_event.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelCieSignFlutter();
  const MethodChannel channel = MethodChannel('cie_sign_flutter');
  const String eventChannelName = 'cie_sign_flutter/nfc_events';
  const StandardMethodCodec eventCodec = StandardMethodCodec();
  MethodCall? lastCall;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          lastCall = methodCall;
          switch (methodCall.method) {
            case 'mockSignPdf':
              final args = methodCall.arguments as Map;
              expect(args['outputPath'], '/tmp/out.pdf');
              final appearance = args['appearance'] as Map?;
              expect(appearance?['pageIndex'], 2);
              expect((appearance?['signatureImage'] as Uint8List?)?.length, 2);
              expect(appearance?['fieldIds'], ['FieldA']);
              return Uint8List.fromList([4, 5, 6]);
            case 'signPdfWithNfc':
              final args = methodCall.arguments as Map;
              expect(args['pin'], '25051980');
              final appearance = args['appearance'] as Map;
              expect(appearance['pageIndex'], 1);
              expect(appearance['left'], 20);
              expect(appearance['reason'], 'Motivo');
              expect(appearance['fieldIds'], ['FieldB']);
              return Uint8List.fromList([7, 8, 9]);
            case 'verifyPinWithNfc':
              final args = methodCall.arguments as Map;
              expect(args['pin'], '25051980');
              return true;
            case 'cancelNfcSigning':
              return true;
            default:
              fail('Unexpected method ${methodCall.method}');
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannelName, (ByteData? message) async {
          if (message == null) return null;
          final MethodCall call = eventCodec.decodeMethodCall(message);
          if (call.method == 'listen' || call.method == 'cancel') {
            return eventCodec.encodeSuccessEnvelope(null);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannelName, null);
  });

  test('mockSignPdf via method channel', () async {
    final response = await platform.mockSignPdf(
      Uint8List.fromList([1, 2, 3]),
      outputPath: '/tmp/out.pdf',
      appearance: PdfSignatureAppearance(
        pageIndex: 2,
        fieldIds: const ['FieldA'],
        signatureImageBytes: Uint8List.fromList([1, 2]),
      ),
    );
    expect(response, Uint8List.fromList([4, 5, 6]));
  });

  test('signPdfWithNfc via method channel', () async {
    final response = await platform.signPdfWithNfc(
      Uint8List.fromList([9, 9, 9]),
      pin: '25051980',
      appearance: const PdfSignatureAppearance(
        pageIndex: 1,
        left: 20,
        reason: 'Motivo',
        fieldIds: ['FieldB'],
      ),
      outputPath: '/tmp/nfc.pdf',
    );
    expect(response, Uint8List.fromList([7, 8, 9]));
    expect(lastCall?.method, 'signPdfWithNfc');
  });

  test('cancelNfcSigning via method channel', () async {
    final canceled = await platform.cancelNfcSigning();
    expect(canceled, isTrue);
    expect(lastCall?.method, 'cancelNfcSigning');
  });

  test('verifyPinWithNfc via method channel', () async {
    final verified = await platform.verifyPinWithNfc(pin: '25051980');
    expect(verified, isTrue);
    expect(lastCall?.method, 'verifyPinWithNfc');
  });

  test('watchNfcEvents emits mapped events', () async {
    final events = <NfcSessionEvent>[];
    final sub = platform.watchNfcEvents().listen(events.add);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          eventChannelName,
          eventCodec.encodeSuccessEnvelope(<String, dynamic>{
            'type': 'state',
            'status': 'ready',
          }),
          (_) {},
        );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events, isNotEmpty);
    expect(events.first.type, NfcSessionEventType.state);
    await sub.cancel();
  });
}
