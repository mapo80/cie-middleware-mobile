import 'dart:typed_data';

/// Type of visual signature to apply to the PDF.
enum SignatureType {
  /// No visual signature (cryptographic signature only)
  none,

  /// Manual signature drawn by the user
  manual,

  /// Auto-generated signature from signer name using Style Script font
  automatic,
}

class PdfSignatureAppearance {
  final int pageIndex;
  final double left;
  final double bottom;
  final double width;
  final double height;
  final String? reason;
  final String? location;
  final String? name;
  final List<String>? fieldIds;
  final Uint8List? signatureImageBytes;

  /// If true and signatureImageBytes is null, auto-generate signature from signer name.
  final bool useAutoSignature;

  /// Override signer name for auto-generated signature (optional).
  /// If null, the name is extracted from the CIE certificate.
  final String? signerNameOverride;

  const PdfSignatureAppearance({
    this.pageIndex = 0,
    this.left = 0,
    this.bottom = 0,
    this.width = 0,
    this.height = 0,
    this.reason,
    this.location,
    this.name,
    this.fieldIds,
    this.signatureImageBytes,
    this.useAutoSignature = false,
    this.signerNameOverride,
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
      if (fieldIds != null && fieldIds!.isNotEmpty) 'fieldIds': fieldIds,
      if (signatureImageBytes != null) 'signatureImage': signatureImageBytes,
      'useAutoSignature': useAutoSignature,
      if (signerNameOverride != null) 'signerNameOverride': signerNameOverride,
    };
  }
}
