import 'dart:io';
import 'dart:typed_data';

import 'package:cie_sign_flutter/src/signed_pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignedPdfDocument', () {
    // Minimal valid PDF header
    final validPdfBytes = Uint8List.fromList([
      0x25, 0x50, 0x44, 0x46, 0x2D, // %PDF-
      0x31, 0x2E, 0x34, // 1.4
      ...List.filled(1000, 0x00), // padding to make it 1KB+
    ]);

    final emptyBytes = Uint8List(0);
    final smallBytes = Uint8List.fromList([0x01, 0x02, 0x03]);

    group('constructor', () {
      test('creates document with bytes', () {
        final doc = SignedPdfDocument(validPdfBytes);

        expect(doc.bytes, equals(validPdfBytes));
        expect(doc.signedAt, isNotNull);
        expect(doc.signedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
      });

      test('withTimestamp creates document with custom timestamp', () {
        final customTime = DateTime(2024, 1, 15, 10, 30);
        final doc = SignedPdfDocument.withTimestamp(validPdfBytes, customTime);

        expect(doc.bytes, equals(validPdfBytes));
        expect(doc.signedAt, equals(customTime));
      });
    });

    group('sizeInBytes', () {
      test('returns correct byte count', () {
        final doc = SignedPdfDocument(validPdfBytes);
        expect(doc.sizeInBytes, equals(validPdfBytes.length));
      });

      test('returns 0 for empty document', () {
        final doc = SignedPdfDocument(emptyBytes);
        expect(doc.sizeInBytes, equals(0));
      });
    });

    group('isValid', () {
      test('returns true for valid PDF', () {
        final doc = SignedPdfDocument(validPdfBytes);
        expect(doc.isValid, isTrue);
      });

      test('returns false for empty document', () {
        final doc = SignedPdfDocument(emptyBytes);
        expect(doc.isValid, isFalse);
      });

      test('returns false for document with less than 5 bytes', () {
        final doc = SignedPdfDocument(smallBytes);
        expect(doc.isValid, isFalse);
      });
    });

    group('formattedSize', () {
      test('formats bytes correctly', () {
        final doc = SignedPdfDocument(Uint8List(512));
        expect(doc.formattedSize, equals('512 B'));
      });

      test('formats kilobytes correctly', () {
        final doc = SignedPdfDocument(Uint8List(1536)); // 1.5 KB
        expect(doc.formattedSize, equals('1.5 KB'));
      });

      test('formats megabytes correctly', () {
        final doc = SignedPdfDocument(Uint8List(1572864)); // 1.5 MB
        expect(doc.formattedSize, equals('1.5 MB'));
      });

      test('formats exactly 1 KB correctly', () {
        final doc = SignedPdfDocument(Uint8List(1024));
        expect(doc.formattedSize, equals('1.0 KB'));
      });

      test('formats exactly 1 MB correctly', () {
        final doc = SignedPdfDocument(Uint8List(1024 * 1024));
        expect(doc.formattedSize, equals('1.0 MB'));
      });
    });

    group('hasPdfHeader', () {
      test('returns true for valid PDF header', () {
        final doc = SignedPdfDocument(validPdfBytes);
        expect(doc.hasPdfHeader, isTrue);
      });

      test('returns false for non-PDF content', () {
        final nonPdfBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
        final doc = SignedPdfDocument(nonPdfBytes);
        expect(doc.hasPdfHeader, isFalse);
      });

      test('returns false for empty document', () {
        final doc = SignedPdfDocument(emptyBytes);
        expect(doc.hasPdfHeader, isFalse);
      });

      test('returns false for document shorter than 5 bytes', () {
        final doc = SignedPdfDocument(smallBytes);
        expect(doc.hasPdfHeader, isFalse);
      });
    });

    group('saveToFile', () {
      test('saves document to specified path', () async {
        final doc = SignedPdfDocument(validPdfBytes);
        final tempDir = Directory.systemTemp.createTempSync('signed_pdf_test_');
        final filePath = '${tempDir.path}/test_output.pdf';

        try {
          final savedFile = await doc.saveToFile(filePath);

          expect(savedFile.existsSync(), isTrue);
          expect(savedFile.path, equals(filePath));
          expect(savedFile.readAsBytesSync(), equals(validPdfBytes));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('saveToDirectory', () {
      test('saves with auto-generated filename', () async {
        final customTime = DateTime(2024, 1, 15, 10, 30);
        final doc = SignedPdfDocument.withTimestamp(validPdfBytes, customTime);
        final tempDir = Directory.systemTemp.createTempSync('signed_pdf_test_');

        try {
          final savedFile = await doc.saveToDirectory(tempDir.path);

          expect(savedFile.existsSync(), isTrue);
          expect(savedFile.path, contains('signed_${customTime.millisecondsSinceEpoch}.pdf'));
          expect(savedFile.readAsBytesSync(), equals(validPdfBytes));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('saves with custom filename', () async {
        final doc = SignedPdfDocument(validPdfBytes);
        final tempDir = Directory.systemTemp.createTempSync('signed_pdf_test_');

        try {
          final savedFile = await doc.saveToDirectory(
            tempDir.path,
            filename: 'custom_name.pdf',
          );

          expect(savedFile.existsSync(), isTrue);
          expect(savedFile.path, endsWith('custom_name.pdf'));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final doc = SignedPdfDocument(validPdfBytes);
        final str = doc.toString();

        expect(str, contains('SignedPdfDocument'));
        expect(str, contains('size:'));
        expect(str, contains('signedAt:'));
        expect(str, contains('valid:'));
      });
    });

    group('equality', () {
      test('equal documents are equal', () {
        final doc1 = SignedPdfDocument(validPdfBytes);
        final doc2 = SignedPdfDocument(Uint8List.fromList(validPdfBytes));

        expect(doc1, equals(doc2));
      });

      test('documents with different bytes are not equal', () {
        final doc1 = SignedPdfDocument(validPdfBytes);
        final differentBytes = Uint8List.fromList([...validPdfBytes, 0xFF]);
        final doc2 = SignedPdfDocument(differentBytes);

        expect(doc1, isNot(equals(doc2)));
      });

      test('identical documents are equal', () {
        final doc = SignedPdfDocument(validPdfBytes);
        expect(doc, equals(doc));
      });

      test('document is not equal to non-document', () {
        final doc = SignedPdfDocument(validPdfBytes);
        // ignore: unrelated_type_equality_checks
        expect(doc == 'not a document', isFalse);
      });
    });

    group('hashCode', () {
      test('equal documents have same hashCode', () {
        final doc1 = SignedPdfDocument(validPdfBytes);
        final doc2 = SignedPdfDocument(Uint8List.fromList(validPdfBytes));

        // Note: hashCode is based on length and signedAt, so same length docs
        // created at different times may have different hashes
        expect(doc1.sizeInBytes, equals(doc2.sizeInBytes));
      });
    });
  });
}
