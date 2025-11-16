import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelCieSignFlutter();
  const MethodChannel channel = MethodChannel('cie_sign_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        expect(methodCall.method, 'mockSignPdf');
        final args = methodCall.arguments as Map;
        expect(args['outputPath'], '/tmp/out.pdf');
        return Uint8List.fromList([4, 5, 6]);
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
    );
    expect(response, Uint8List.fromList([4, 5, 6]));
  });
}
