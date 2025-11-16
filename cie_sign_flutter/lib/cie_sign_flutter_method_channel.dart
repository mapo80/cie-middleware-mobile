import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cie_sign_flutter_platform_interface.dart';

class MethodChannelCieSignFlutter extends CieSignFlutterPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('cie_sign_flutter');

  @override
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
  }) async {
    final Uint8List? response = await methodChannel.invokeMethod<Uint8List>(
      'mockSignPdf',
      <String, dynamic>{
        'pdf': pdfBytes,
        if (outputPath != null) 'outputPath': outputPath,
      },
    );
    if (response == null) {
      throw StateError('mockSignPdf returned null');
    }
    return response;
  }
}
