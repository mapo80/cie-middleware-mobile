import 'dart:typed_data';

import 'cie_sign_flutter_platform_interface.dart';

class CieSignFlutter {
  Future<Uint8List> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
  }) {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    return CieSignFlutterPlatform.instance.mockSignPdf(
      pdfBytes,
      outputPath: outputPath,
    );
  }
}
