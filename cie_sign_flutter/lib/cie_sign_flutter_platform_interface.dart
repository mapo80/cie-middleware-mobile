import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'cie_sign_flutter_method_channel.dart';
import 'src/nfc_session_event.dart';
import 'src/pdf_signature_appearance.dart';

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
    PdfSignatureAppearance? appearance,
  }) {
    throw UnimplementedError('mockSignPdf() has not been implemented.');
  }

  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) {
    throw UnimplementedError('signPdfWithNfc() has not been implemented.');
  }

  Future<bool> verifyPinWithNfc({required String pin}) {
    throw UnimplementedError('verifyPinWithNfc() has not been implemented.');
  }

  Future<bool> cancelNfcSigning() {
    throw UnimplementedError('cancelNfcSigning() has not been implemented.');
  }

  Stream<NfcSessionEvent> watchNfcEvents() {
    throw UnimplementedError('watchNfcEvents() has not been implemented.');
  }
}
