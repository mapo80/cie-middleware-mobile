import 'dart:typed_data';

import 'package:cie_sign_flutter/cie_sign_flutter_method_channel.dart';
import 'package:cie_sign_flutter/src/pdf_signature_appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelCieSignFlutter();
  const MethodChannel channel = MethodChannel('cie_sign_flutter');

  group('Auto-signature method channel tests', () {
    Map<dynamic, dynamic>? capturedAppearance;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        final args = methodCall.arguments as Map;
        capturedAppearance = args['appearance'] as Map<dynamic, dynamic>?;
        return Uint8List.fromList([1, 2, 3]);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      capturedAppearance = null;
    });

    test('mockSignPdf passes useAutoSignature=true', () async {
      await platform.mockSignPdf(
        Uint8List.fromList([1, 2, 3]),
        appearance: const PdfSignatureAppearance(
          pageIndex: 0,
          useAutoSignature: true,
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['useAutoSignature'], isTrue);
    });

    test('mockSignPdf passes useAutoSignature=false', () async {
      await platform.mockSignPdf(
        Uint8List.fromList([1, 2, 3]),
        appearance: const PdfSignatureAppearance(
          pageIndex: 0,
          useAutoSignature: false,
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['useAutoSignature'], isFalse);
    });

    test('mockSignPdf passes signerNameOverride', () async {
      await platform.mockSignPdf(
        Uint8List.fromList([1, 2, 3]),
        appearance: const PdfSignatureAppearance(
          useAutoSignature: true,
          signerNameOverride: 'Mario Rossi',
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['signerNameOverride'], 'Mario Rossi');
    });

    test('mockSignPdf excludes signerNameOverride when null', () async {
      await platform.mockSignPdf(
        Uint8List.fromList([1, 2, 3]),
        appearance: const PdfSignatureAppearance(
          useAutoSignature: true,
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!.containsKey('signerNameOverride'), isFalse);
    });

    test('signPdfWithNfc passes auto-signature fields', () async {
      await platform.signPdfWithNfc(
        Uint8List.fromList([1, 2, 3]),
        pin: '1234',
        appearance: const PdfSignatureAppearance(
          pageIndex: 1,
          useAutoSignature: true,
          signerNameOverride: 'Giulia Bianchi',
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['pageIndex'], 1);
      expect(capturedAppearance!['useAutoSignature'], isTrue);
      expect(capturedAppearance!['signerNameOverride'], 'Giulia Bianchi');
    });

    test('signPdfWithNfc with manual signature mode', () async {
      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      await platform.signPdfWithNfc(
        Uint8List.fromList([1, 2, 3]),
        pin: '1234',
        appearance: PdfSignatureAppearance(
          pageIndex: 0,
          signatureImageBytes: imageBytes,
          useAutoSignature: false,
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['useAutoSignature'], isFalse);
      expect(capturedAppearance!['signatureImage'], imageBytes);
    });

    test('complete appearance map with all fields', () async {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);

      await platform.mockSignPdf(
        Uint8List.fromList([1, 2, 3]),
        appearance: PdfSignatureAppearance(
          pageIndex: 2,
          left: 100.0,
          bottom: 200.0,
          width: 300.0,
          height: 80.0,
          reason: 'Test reason',
          location: 'Test location',
          name: 'Test name',
          fieldIds: const ['field1', 'field2'],
          signatureImageBytes: imageBytes,
          useAutoSignature: false,
          signerNameOverride: 'Override Name',
        ),
      );

      expect(capturedAppearance, isNotNull);
      expect(capturedAppearance!['pageIndex'], 2);
      expect(capturedAppearance!['left'], 100.0);
      expect(capturedAppearance!['bottom'], 200.0);
      expect(capturedAppearance!['width'], 300.0);
      expect(capturedAppearance!['height'], 80.0);
      expect(capturedAppearance!['reason'], 'Test reason');
      expect(capturedAppearance!['location'], 'Test location');
      expect(capturedAppearance!['name'], 'Test name');
      expect(capturedAppearance!['fieldIds'], ['field1', 'field2']);
      expect(capturedAppearance!['signatureImage'], imageBytes);
      expect(capturedAppearance!['useAutoSignature'], isFalse);
      expect(capturedAppearance!['signerNameOverride'], 'Override Name');
    });
  });

  group('SignatureType enum tests', () {
    test('SignatureType.none has index 0', () {
      expect(SignatureType.none.index, 0);
    });

    test('SignatureType.manual has index 1', () {
      expect(SignatureType.manual.index, 1);
    });

    test('SignatureType.automatic has index 2', () {
      expect(SignatureType.automatic.index, 2);
    });

    test('SignatureType values are iterable', () {
      expect(SignatureType.values.length, 3);
      expect(SignatureType.values[0], SignatureType.none);
      expect(SignatureType.values[1], SignatureType.manual);
      expect(SignatureType.values[2], SignatureType.automatic);
    });
  });

  group('PdfSignatureAppearance default values', () {
    test('useAutoSignature defaults to false', () {
      const appearance = PdfSignatureAppearance();
      expect(appearance.useAutoSignature, isFalse);
    });

    test('signerNameOverride defaults to null', () {
      const appearance = PdfSignatureAppearance();
      expect(appearance.signerNameOverride, isNull);
    });

    test('toMap includes useAutoSignature even when false', () {
      const appearance = PdfSignatureAppearance();
      final map = appearance.toMap();
      expect(map.containsKey('useAutoSignature'), isTrue);
      expect(map['useAutoSignature'], isFalse);
    });

    test('toMap excludes signerNameOverride when null', () {
      const appearance = PdfSignatureAppearance();
      final map = appearance.toMap();
      expect(map.containsKey('signerNameOverride'), isFalse);
    });
  });
}
