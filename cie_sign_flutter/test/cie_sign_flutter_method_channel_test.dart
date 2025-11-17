import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelCieSignFlutter();
  const MethodChannel channel = MethodChannel('cie_sign_flutter');
  MethodCall? lastCall;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
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
            expect(args['pin'], '12345678');
            final appearance = args['appearance'] as Map;
            expect(appearance['pageIndex'], 1);
            expect(appearance['left'], 20);
            expect(appearance['reason'], 'Motivo');
            expect(appearance['fieldIds'], ['FieldB']);
            return Uint8List.fromList([7, 8, 9]);
          case 'cancelNfcSigning':
            return true;
          default:
            fail('Unexpected method ${methodCall.method}');
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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
      pin: '12345678',
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
}
