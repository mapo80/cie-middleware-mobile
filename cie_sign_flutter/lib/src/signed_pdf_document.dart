import 'dart:io';
import 'dart:typed_data';

/// Rappresenta un documento PDF firmato digitalmente con CIE.
///
/// Questa classe wrappa i byte grezzi del PDF firmato e fornisce
/// metodi helper per salvare, condividere e ispezionare il documento.
///
/// Esempio:
/// ```dart
/// final signedDoc = await cieSign.signPdfWithNfc(pdfBytes, pin: pin, appearance: appearance);
/// print('Dimensione: ${signedDoc.formattedSize}');
/// await signedDoc.saveToFile('/path/to/output.pdf');
/// ```
class SignedPdfDocument {
  /// I byte grezzi del PDF firmato.
  final Uint8List bytes;

  /// Timestamp di quando il documento è stato firmato.
  final DateTime signedAt;

  /// Crea un nuovo documento PDF firmato.
  SignedPdfDocument(this.bytes) : signedAt = DateTime.now();

  /// Crea un documento PDF firmato con timestamp personalizzato (per test).
  SignedPdfDocument.withTimestamp(this.bytes, this.signedAt);

  /// Dimensione del documento in byte.
  int get sizeInBytes => bytes.length;

  /// Restituisce true se il documento contiene dati validi.
  bool get isValid => bytes.isNotEmpty && bytes.length > 4;

  /// Dimensione formattata in unità leggibili (B, KB, MB).
  ///
  /// Esempi:
  /// - 512 bytes → "512 B"
  /// - 1536 bytes → "1.5 KB"
  /// - 1572864 bytes → "1.5 MB"
  String get formattedSize {
    if (bytes.length < 1024) {
      return '${bytes.length} B';
    }
    if (bytes.length < 1024 * 1024) {
      return '${(bytes.length / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Salva il PDF firmato su file nel percorso specificato.
  ///
  /// Restituisce il [File] creato.
  ///
  /// Esempio:
  /// ```dart
  /// final file = await signedDoc.saveToFile('/path/to/signed.pdf');
  /// print('Salvato in: ${file.path}');
  /// ```
  Future<File> saveToFile(String path) async {
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Salva il PDF firmato in una directory specificata con nome auto-generato.
  ///
  /// Il nome del file segue il pattern: `signed_<timestamp>.pdf`
  /// dove timestamp è in millisecondi dall'epoch.
  ///
  /// Esempio:
  /// ```dart
  /// final file = await signedDoc.saveToDirectory('/path/to/documents');
  /// // Crea: /path/to/documents/signed_1234567890123.pdf
  /// ```
  Future<File> saveToDirectory(String directoryPath, {String? filename}) async {
    final name = filename ?? 'signed_${signedAt.millisecondsSinceEpoch}.pdf';
    final path = '$directoryPath/$name';
    return saveToFile(path);
  }

  /// Verifica se i byte iniziano con la firma PDF (%PDF-).
  ///
  /// Questo è un controllo basilare per verificare che il contenuto
  /// sia effettivamente un PDF.
  bool get hasPdfHeader {
    if (bytes.length < 5) return false;
    // %PDF- in ASCII
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  @override
  String toString() {
    return 'SignedPdfDocument(size: $formattedSize, signedAt: $signedAt, valid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignedPdfDocument) return false;
    if (bytes.length != other.bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(bytes.length, signedAt);
}
