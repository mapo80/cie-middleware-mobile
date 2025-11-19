import 'dart:typed_data';

import 'cie_sign_flutter_platform_interface.dart';
import 'src/nfc_session_event.dart';
import 'src/pdf_signature_appearance.dart';

export 'src/pdf_signature_appearance.dart';
export 'src/nfc_session_event.dart';

class CieSignFlutter {
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    return CieSignFlutterPlatform.instance.mockSignPdf(
      pdfBytes,
      outputPath: outputPath,
      appearance: appearance,
    );
  }

  Future<Uint8List> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    if (pin.isEmpty) {
      throw ArgumentError('PIN cannot be empty');
    }
    return CieSignFlutterPlatform.instance.signPdfWithNfc(
      pdfBytes,
      pin: pin,
      appearance: appearance,
      outputPath: outputPath,
    );
  }

  Future<bool> verifyPinWithNfc({required String pin}) {
    if (pin.isEmpty) {
      throw ArgumentError('PIN cannot be empty');
    }
    return CieSignFlutterPlatform.instance.verifyPinWithNfc(pin: pin);
  }

  Future<bool> cancelNfcSigning() {
    return CieSignFlutterPlatform.instance.cancelNfcSigning();
  }

  Stream<NfcSessionEvent> watchNfcEvents() {
    return CieSignFlutterPlatform.instance.watchNfcEvents();
  }
}
