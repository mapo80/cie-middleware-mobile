/// Information about a signature field in a PDF document.
///
/// Use [CieSignFlutter.extractSignatureFields] to get a list of these
/// for any PDF document.
class PdfSignatureFieldInfo {
  /// Unique name of the signature field (e.g., "SignatureField1").
  final String name;

  /// Page index where the field is located (0-based).
  final int pageIndex;

  /// X position of the field in PDF points.
  final double left;

  /// Y position of the field in PDF points (from bottom).
  final double bottom;

  /// Width of the field in PDF points.
  final double width;

  /// Height of the field in PDF points.
  final double height;

  /// Whether the field already contains a signature.
  final bool isSigned;

  const PdfSignatureFieldInfo({
    required this.name,
    required this.pageIndex,
    required this.left,
    required this.bottom,
    required this.width,
    required this.height,
    required this.isSigned,
  });

  /// Creates a [PdfSignatureFieldInfo] from a map returned by the native layer.
  factory PdfSignatureFieldInfo.fromMap(Map<dynamic, dynamic> map) {
    return PdfSignatureFieldInfo(
      name: (map['name'] as String?) ?? '',
      pageIndex: (map['pageIndex'] as num?)?.toInt() ?? 0,
      left: (map['left'] as num?)?.toDouble() ?? 0.0,
      bottom: (map['bottom'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      isSigned: (map['isSigned'] as bool?) ?? false,
    );
  }

  /// Converts this field info to a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pageIndex': pageIndex,
      'left': left,
      'bottom': bottom,
      'width': width,
      'height': height,
      'isSigned': isSigned,
    };
  }

  @override
  String toString() {
    return 'PdfSignatureFieldInfo('
        'name: $name, '
        'pageIndex: $pageIndex, '
        'rect: ($left, $bottom, $width, $height), '
        'isSigned: $isSigned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfSignatureFieldInfo) return false;
    return name == other.name &&
        pageIndex == other.pageIndex &&
        left == other.left &&
        bottom == other.bottom &&
        width == other.width &&
        height == other.height &&
        isSigned == other.isSigned;
  }

  @override
  int get hashCode => Object.hash(
        name,
        pageIndex,
        left,
        bottom,
        width,
        height,
        isSigned,
      );
}
