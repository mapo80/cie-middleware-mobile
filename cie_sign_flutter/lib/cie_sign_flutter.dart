import 'dart:typed_data';

import 'cie_sign_flutter_platform_interface.dart';
import 'src/nfc_session_event.dart';
import 'src/pdf_signature_appearance.dart';
import 'src/pdf_signature_field_info.dart';
import 'src/signed_pdf_document.dart';

export 'src/pdf_signature_appearance.dart';
export 'src/nfc_session_event.dart';
export 'src/pdf_signature_field_info.dart';
export 'src/signed_pdf_document.dart';

// Hand signature widget exports
export 'src/widgets/cie_hand_signature.dart';
export 'src/widgets/cie_hand_signature_controller.dart';
export 'src/widgets/cie_hand_signature_config.dart';

class CieSignFlutter {
  /// Firma un PDF con un certificato mock (per test, senza NFC).
  ///
  /// Restituisce un [SignedPdfDocument] contenente il PDF firmato.
  ///
  /// Esempio:
  /// ```dart
  /// final signedDoc = await cieSign.mockSignPdf(pdfBytes, appearance: appearance);
  /// print('Firmato: ${signedDoc.formattedSize}');
  /// await signedDoc.saveToFile('/path/to/output.pdf');
  /// ```
  Future<SignedPdfDocument> mockSignPdf(
    Uint8List pdfBytes, {
    String? outputPath,
    PdfSignatureAppearance? appearance,
  }) async {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    final bytes = await CieSignFlutterPlatform.instance.mockSignPdf(
      pdfBytes,
      outputPath: outputPath,
      appearance: appearance,
    );
    return SignedPdfDocument(bytes);
  }

  /// Firma un PDF con la CIE via NFC.
  ///
  /// Richiede il [pin] della CIE e attende che l'utente avvicini la carta.
  /// Restituisce un [SignedPdfDocument] contenente il PDF firmato digitalmente.
  ///
  /// Esempio:
  /// ```dart
  /// final signedDoc = await cieSign.signPdfWithNfc(
  ///   pdfBytes,
  ///   pin: '12345678',
  ///   appearance: PdfSignatureAppearance(
  ///     fieldIds: ['SignatureField1'],
  ///     reason: 'Approvazione',
  ///   ),
  /// );
  /// await signedDoc.saveToFile('/documenti/contratto_firmato.pdf');
  /// ```
  Future<SignedPdfDocument> signPdfWithNfc(
    Uint8List pdfBytes, {
    required String pin,
    PdfSignatureAppearance appearance = const PdfSignatureAppearance(),
    String? outputPath,
  }) async {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    if (pin.isEmpty) {
      throw ArgumentError('PIN cannot be empty');
    }
    final bytes = await CieSignFlutterPlatform.instance.signPdfWithNfc(
      pdfBytes,
      pin: pin,
      appearance: appearance,
      outputPath: outputPath,
    );
    return SignedPdfDocument(bytes);
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

  /// Estrae i campi firma da un documento PDF.
  ///
  /// Restituisce una lista di [PdfSignatureFieldInfo] con le informazioni
  /// su ciascun campo firma trovato nel PDF (nome, posizione, se firmato, ecc.).
  ///
  /// Esempio:
  /// ```dart
  /// final fields = await cieSign.extractSignatureFields(pdfBytes);
  /// for (final field in fields) {
  ///   print('Campo: ${field.name}, firmato: ${field.isSigned}');
  /// }
  ///
  /// // Firma solo i campi non firmati
  /// final unsigned = fields.where((f) => !f.isSigned).map((f) => f.name).toList();
  /// final signedDoc = await cieSign.signPdfWithNfc(
  ///   pdfBytes,
  ///   pin: pin,
  ///   appearance: PdfSignatureAppearance(fieldIds: unsigned),
  /// );
  /// ```
  Future<List<PdfSignatureFieldInfo>> extractSignatureFields(
      Uint8List pdfBytes) {
    if (pdfBytes.isEmpty) {
      throw ArgumentError('PDF input cannot be empty');
    }
    return CieSignFlutterPlatform.instance.extractSignatureFields(pdfBytes);
  }
}
