import 'package:cie_sign_flutter/src/pdf_signature_field_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfSignatureFieldInfo', () {
    group('constructor', () {
      test('creates instance with all required parameters', () {
        final info = PdfSignatureFieldInfo(
          name: 'SignatureField1',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        expect(info.name, equals('SignatureField1'));
        expect(info.pageIndex, equals(0));
        expect(info.left, equals(100.0));
        expect(info.bottom, equals(200.0));
        expect(info.width, equals(150.0));
        expect(info.height, equals(50.0));
        expect(info.isSigned, isFalse);
      });
    });

    group('fromMap', () {
      test('parses complete map correctly', () {
        final map = {
          'name': 'TestField',
          'pageIndex': 2,
          'left': 50.5,
          'bottom': 100.5,
          'width': 200.0,
          'height': 75.0,
          'isSigned': true,
        };

        final info = PdfSignatureFieldInfo.fromMap(map);

        expect(info.name, equals('TestField'));
        expect(info.pageIndex, equals(2));
        expect(info.left, equals(50.5));
        expect(info.bottom, equals(100.5));
        expect(info.width, equals(200.0));
        expect(info.height, equals(75.0));
        expect(info.isSigned, isTrue);
      });

      test('handles missing values with defaults', () {
        final info = PdfSignatureFieldInfo.fromMap({});

        expect(info.name, equals(''));
        expect(info.pageIndex, equals(0));
        expect(info.left, equals(0.0));
        expect(info.bottom, equals(0.0));
        expect(info.width, equals(0.0));
        expect(info.height, equals(0.0));
        expect(info.isSigned, isFalse);
      });

      test('handles integer values for doubles', () {
        final map = {
          'name': 'Field',
          'pageIndex': 1,
          'left': 100,
          'bottom': 200,
          'width': 150,
          'height': 50,
          'isSigned': false,
        };

        final info = PdfSignatureFieldInfo.fromMap(map);

        expect(info.left, equals(100.0));
        expect(info.bottom, equals(200.0));
        expect(info.width, equals(150.0));
        expect(info.height, equals(50.0));
      });

      test('handles null values', () {
        final map = {
          'name': null,
          'pageIndex': null,
          'left': null,
          'bottom': null,
          'width': null,
          'height': null,
          'isSigned': null,
        };

        final info = PdfSignatureFieldInfo.fromMap(map);

        expect(info.name, equals(''));
        expect(info.pageIndex, equals(0));
        expect(info.left, equals(0.0));
        expect(info.isSigned, isFalse);
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final info = PdfSignatureFieldInfo(
          name: 'ExportField',
          pageIndex: 3,
          left: 75.0,
          bottom: 125.0,
          width: 180.0,
          height: 60.0,
          isSigned: true,
        );

        final map = info.toMap();

        expect(map['name'], equals('ExportField'));
        expect(map['pageIndex'], equals(3));
        expect(map['left'], equals(75.0));
        expect(map['bottom'], equals(125.0));
        expect(map['width'], equals(180.0));
        expect(map['height'], equals(60.0));
        expect(map['isSigned'], isTrue);
      });

      test('roundtrip conversion preserves data', () {
        final original = PdfSignatureFieldInfo(
          name: 'RoundtripField',
          pageIndex: 5,
          left: 122.4,
          bottom: 514.8,
          width: 306.0,
          height: 158.4,
          isSigned: false,
        );

        final map = original.toMap();
        final restored = PdfSignatureFieldInfo.fromMap(map);

        expect(restored, equals(original));
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final info = PdfSignatureFieldInfo(
          name: 'ToStringField',
          pageIndex: 1,
          left: 50.0,
          bottom: 100.0,
          width: 200.0,
          height: 75.0,
          isSigned: true,
        );

        final str = info.toString();

        expect(str, contains('PdfSignatureFieldInfo'));
        expect(str, contains('ToStringField'));
        expect(str, contains('pageIndex: 1'));
        expect(str, contains('isSigned: true'));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        final info1 = PdfSignatureFieldInfo(
          name: 'EqualField',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        final info2 = PdfSignatureFieldInfo(
          name: 'EqualField',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        expect(info1, equals(info2));
        expect(info1.hashCode, equals(info2.hashCode));
      });

      test('different name makes unequal', () {
        final info1 = PdfSignatureFieldInfo(
          name: 'Field1',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        final info2 = PdfSignatureFieldInfo(
          name: 'Field2',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        expect(info1, isNot(equals(info2)));
      });

      test('different isSigned makes unequal', () {
        final info1 = PdfSignatureFieldInfo(
          name: 'Field',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: false,
        );

        final info2 = PdfSignatureFieldInfo(
          name: 'Field',
          pageIndex: 0,
          left: 100.0,
          bottom: 200.0,
          width: 150.0,
          height: 50.0,
          isSigned: true,
        );

        expect(info1, isNot(equals(info2)));
      });

      test('identical instance equals itself', () {
        final info = PdfSignatureFieldInfo(
          name: 'Self',
          pageIndex: 0,
          left: 0.0,
          bottom: 0.0,
          width: 0.0,
          height: 0.0,
          isSigned: false,
        );

        expect(info, equals(info));
      });

      test('not equal to non-PdfSignatureFieldInfo', () {
        final info = PdfSignatureFieldInfo(
          name: 'Field',
          pageIndex: 0,
          left: 0.0,
          bottom: 0.0,
          width: 0.0,
          height: 0.0,
          isSigned: false,
        );

        // ignore: unrelated_type_equality_checks
        expect(info == 'not a field info', isFalse);
      });
    });
  });
}
