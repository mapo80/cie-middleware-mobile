import 'dart:typed_data';

class PdfSignatureAppearance {
  final int pageIndex;
  final double left;
  final double bottom;
  final double width;
  final double height;
  final String? reason;
  final String? location;
  final String? name;
  final Uint8List? signatureImageBytes;

  const PdfSignatureAppearance({
    this.pageIndex = 0,
    this.left = 0,
    this.bottom = 0,
    this.width = 0,
    this.height = 0,
    this.reason,
    this.location,
    this.name,
    this.signatureImageBytes,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pageIndex': pageIndex,
      'left': left,
      'bottom': bottom,
      'width': width,
      'height': height,
      if (reason != null) 'reason': reason,
      if (location != null) 'location': location,
      if (name != null) 'name': name,
      if (signatureImageBytes != null) 'signatureImage': signatureImageBytes,
    };
  }
}
