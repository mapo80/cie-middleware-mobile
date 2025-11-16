import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'cie_sign_flutter_method_channel.dart';

abstract class CieSignFlutterPlatform extends PlatformInterface {
  CieSignFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static CieSignFlutterPlatform _instance = MethodChannelCieSignFlutter();

  static CieSignFlutterPlatform get instance => _instance;

  static set instance(CieSignFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
  }) {
    throw UnimplementedError('mockSignPdf() has not been implemented.');
  }
}
