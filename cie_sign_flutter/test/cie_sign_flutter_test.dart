import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/cie_sign_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCieSignFlutterPlatform
    with MockPlatformInterfaceMixin
    implements CieSignFlutterPlatform {
  Uint8List? lastInput;
  String? lastPath;

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
  }) {
    lastInput = pdfBytes;
    lastPath = outputPath;
    return Future.value(Uint8List.fromList(pdfBytes.reversed.toList()));
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
    );
    expect(fakePlatform.lastInput, equals(input));
    expect(fakePlatform.lastPath, '/tmp/result.pdf');
    expect(result, equals(Uint8List.fromList([4, 3, 2, 1])));
  });
}
