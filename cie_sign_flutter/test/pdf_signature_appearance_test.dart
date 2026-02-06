import 'dart:typed_data';

import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignatureType', () {
    test('enum has expected values', () {
      expect(SignatureType.values, hasLength(3));
      expect(SignatureType.values, contains(SignatureType.none));
      expect(SignatureType.values, contains(SignatureType.manual));
      expect(SignatureType.values, contains(SignatureType.automatic));
    });

    test('enum indices are correct', () {
      expect(SignatureType.none.index, 0);
      expect(SignatureType.manual.index, 1);
      expect(SignatureType.automatic.index, 2);
    });
  });

  group('PdfSignatureAppearance', () {
    test('default constructor has expected defaults', () {
      const appearance = PdfSignatureAppearance();
      expect(appearance.pageIndex, 0);
      expect(appearance.left, 0);
      expect(appearance.bottom, 0);
      expect(appearance.width, 0);
      expect(appearance.height, 0);
      expect(appearance.reason, isNull);
      expect(appearance.location, isNull);
      expect(appearance.name, isNull);
      expect(appearance.fieldIds, isNull);
      expect(appearance.signatureImageBytes, isNull);
      expect(appearance.useAutoSignature, isFalse);
      expect(appearance.signerNameOverride, isNull);
    });

    test('constructor accepts all parameters', () {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      final appearance = PdfSignatureAppearance(
        pageIndex: 5,
        left: 100.5,
        bottom: 200.5,
        width: 300.0,
        height: 100.0,
        reason: 'Test reason',
        location: 'Test location',
        name: 'Test name',
        fieldIds: ['field1', 'field2'],
        signatureImageBytes: imageBytes,
        useAutoSignature: true,
        signerNameOverride: 'Mario Rossi',
      );

      expect(appearance.pageIndex, 5);
      expect(appearance.left, 100.5);
      expect(appearance.bottom, 200.5);
      expect(appearance.width, 300.0);
      expect(appearance.height, 100.0);
      expect(appearance.reason, 'Test reason');
      expect(appearance.location, 'Test location');
      expect(appearance.name, 'Test name');
      expect(appearance.fieldIds, ['field1', 'field2']);
      expect(appearance.signatureImageBytes, imageBytes);
      expect(appearance.useAutoSignature, isTrue);
      expect(appearance.signerNameOverride, 'Mario Rossi');
    });

    group('toMap', () {
      test('includes required fields', () {
        const appearance = PdfSignatureAppearance(
          pageIndex: 2,
          left: 10.0,
          bottom: 20.0,
          width: 150.0,
          height: 50.0,
        );
        final map = appearance.toMap();

        expect(map['pageIndex'], 2);
        expect(map['left'], 10.0);
        expect(map['bottom'], 20.0);
        expect(map['width'], 150.0);
        expect(map['height'], 50.0);
        expect(map['useAutoSignature'], isFalse);
      });

      test('excludes null optional fields', () {
        const appearance = PdfSignatureAppearance();
        final map = appearance.toMap();

        expect(map.containsKey('reason'), isFalse);
        expect(map.containsKey('location'), isFalse);
        expect(map.containsKey('name'), isFalse);
        expect(map.containsKey('fieldIds'), isFalse);
        expect(map.containsKey('signatureImage'), isFalse);
        expect(map.containsKey('signerNameOverride'), isFalse);
      });

      test('includes reason when set', () {
        const appearance = PdfSignatureAppearance(reason: 'Approval');
        final map = appearance.toMap();

        expect(map['reason'], 'Approval');
      });

      test('includes location when set', () {
        const appearance = PdfSignatureAppearance(location: 'Rome');
        final map = appearance.toMap();

        expect(map['location'], 'Rome');
      });

      test('includes name when set', () {
        const appearance = PdfSignatureAppearance(name: 'John Doe');
        final map = appearance.toMap();

        expect(map['name'], 'John Doe');
      });

      test('includes fieldIds when non-empty', () {
        const appearance = PdfSignatureAppearance(
          fieldIds: ['sig1', 'sig2'],
        );
        final map = appearance.toMap();

        expect(map['fieldIds'], ['sig1', 'sig2']);
      });

      test('excludes fieldIds when empty list', () {
        const appearance = PdfSignatureAppearance(fieldIds: []);
        final map = appearance.toMap();

        expect(map.containsKey('fieldIds'), isFalse);
      });

      test('includes signatureImage when set', () {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final appearance = PdfSignatureAppearance(signatureImageBytes: bytes);
        final map = appearance.toMap();

        expect(map['signatureImage'], bytes);
      });

      test('includes useAutoSignature as true when enabled', () {
        const appearance = PdfSignatureAppearance(useAutoSignature: true);
        final map = appearance.toMap();

        expect(map['useAutoSignature'], isTrue);
      });

      test('includes signerNameOverride when set', () {
        const appearance = PdfSignatureAppearance(
          signerNameOverride: 'Giulia Bianchi',
        );
        final map = appearance.toMap();

        expect(map['signerNameOverride'], 'Giulia Bianchi');
      });

      test('complete map with all fields', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final appearance = PdfSignatureAppearance(
          pageIndex: 1,
          left: 50.0,
          bottom: 100.0,
          width: 200.0,
          height: 80.0,
          reason: 'Signing',
          location: 'Milan',
          name: 'Signer',
          fieldIds: ['field1'],
          signatureImageBytes: imageBytes,
          useAutoSignature: true,
          signerNameOverride: 'Custom Name',
        );
        final map = appearance.toMap();

        expect(map, {
          'pageIndex': 1,
          'left': 50.0,
          'bottom': 100.0,
          'width': 200.0,
          'height': 80.0,
          'reason': 'Signing',
          'location': 'Milan',
          'name': 'Signer',
          'fieldIds': ['field1'],
          'signatureImage': imageBytes,
          'useAutoSignature': true,
          'signerNameOverride': 'Custom Name',
        });
      });
    });

    group('auto signature scenarios', () {
      test('manual signature: image bytes set, useAutoSignature false', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final appearance = PdfSignatureAppearance(
          signatureImageBytes: imageBytes,
          useAutoSignature: false,
        );

        expect(appearance.signatureImageBytes, isNotNull);
        expect(appearance.useAutoSignature, isFalse);
        expect(appearance.signerNameOverride, isNull);
      });

      test('automatic signature: no image bytes, useAutoSignature true', () {
        const appearance = PdfSignatureAppearance(
          useAutoSignature: true,
        );

        expect(appearance.signatureImageBytes, isNull);
        expect(appearance.useAutoSignature, isTrue);
      });

      test('automatic signature with name override', () {
        const appearance = PdfSignatureAppearance(
          useAutoSignature: true,
          signerNameOverride: 'Override Name',
        );

        expect(appearance.useAutoSignature, isTrue);
        expect(appearance.signerNameOverride, 'Override Name');
      });

      test('no visual signature: no image, useAutoSignature false', () {
        const appearance = PdfSignatureAppearance(
          useAutoSignature: false,
        );

        expect(appearance.signatureImageBytes, isNull);
        expect(appearance.useAutoSignature, isFalse);
      });
    });
  });
}
