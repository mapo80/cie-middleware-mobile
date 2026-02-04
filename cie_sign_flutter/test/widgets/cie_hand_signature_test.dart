import 'dart:typed_data';

import 'package:cie_sign_flutter/src/widgets/cie_hand_signature.dart';
import 'package:cie_sign_flutter/src/widgets/cie_hand_signature_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CieHandSignatureController', () {
    test('starts empty without initialImage', () {
      final controller = CieHandSignatureController();
      expect(controller.isFilled, isFalse);
      expect(controller.isEmpty, isTrue);
      expect(controller.hasDrawn, isFalse);
      expect(controller.wasCleared, isFalse);
      expect(controller.initialImage, isNull);
      controller.dispose();
    });

    test('initialImage sets isFilled to true', () {
      final image = Uint8List.fromList([1, 2, 3, 4]);
      final controller = CieHandSignatureController(initialImage: image);
      expect(controller.isFilled, isTrue);
      expect(controller.isEmpty, isFalse);
      expect(controller.initialImage, equals(image));
      controller.dispose();
    });

    test('clear() sets wasCleared and resets hasDrawn', () {
      final image = Uint8List.fromList([1, 2, 3, 4]);
      final controller = CieHandSignatureController(initialImage: image);
      expect(controller.isFilled, isTrue);

      controller.clear();

      expect(controller.wasCleared, isTrue);
      expect(controller.hasDrawn, isFalse);
      expect(controller.isFilled, isFalse);
      controller.dispose();
    });

    test('notifies listeners on clear', () {
      final controller = CieHandSignatureController(
        initialImage: Uint8List.fromList([1, 2, 3]),
      );
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clear();

      expect(notified, isTrue);
      controller.dispose();
    });
  });

  group('CieHandSignature - ReadOnly Mode', () {
    testWidgets('shows placeholder when no image and readOnly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
            ),
          ),
        ),
      );

      expect(find.text('Tocca per firmare'), findsOneWidget);
      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
    });

    testWidgets('shows custom placeholder when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              emptyPlaceholder: Text('Custom placeholder'),
            ),
          ),
        ),
      );

      expect(find.text('Custom placeholder'), findsOneWidget);
      expect(find.text('Tocca per firmare'), findsNothing);
    });

    testWidgets('shows image when signatureImage provided', (tester) async {
      // Create a minimal valid PNG (1x1 transparent pixel)
      final pngBytes = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              signatureImage: pngBytes,
              readOnly: true,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Tocca per firmare'), findsNothing);
    });

    testWidgets('hides clear/save buttons in readOnly mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              showButtons: true,
            ),
          ),
        ),
      );

      expect(find.text('Pulisci'), findsNothing);
      expect(find.text('Salva'), findsNothing);
    });

    testWidgets('shows fullscreen button in readOnly mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              showButtons: true,
              showFullscreenButton: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });
  });

  group('CieHandSignature - Drawing Mode', () {
    testWidgets('shows clear and save buttons when readOnly is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: false,
              showButtons: true,
            ),
          ),
        ),
      );

      expect(find.text('Pulisci'), findsOneWidget);
      expect(find.text('Salva'), findsOneWidget);
    });

    testWidgets('displays custom button texts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: false,
              clearButtonText: 'Cancella',
              saveButtonText: 'Conferma',
            ),
          ),
        ),
      );

      expect(find.text('Cancella'), findsOneWidget);
      expect(find.text('Conferma'), findsOneWidget);
    });
  });

  group('CieHandSignature - Buttons Visibility', () {
    testWidgets('shows fullscreen button when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              showFullscreenButton: true,
              showButtons: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('hides fullscreen button when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              showFullscreenButton: false,
              showButtons: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });

    testWidgets('hides all buttons when showButtons is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: false,
              showButtons: false,
            ),
          ),
        ),
      );

      expect(find.text('Pulisci'), findsNothing);
      expect(find.text('Salva'), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });
  });

  group('CieHandSignature - Fullscreen', () {
    testWidgets('tapping readOnly widget opens fullscreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              showFullscreenButton: true,
            ),
          ),
        ),
      );

      // Tap on the signature area
      await tester.tap(find.text('Tocca per firmare'));
      await tester.pumpAndSettle();

      // Should navigate to fullscreen page
      expect(find.text('Firma qui'), findsOneWidget);
    });

    testWidgets('fullscreen cancel returns null', (tester) async {
      Uint8List? savedBytes;
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              showFullscreenButton: true,
              onSignatureSaved: (bytes) {
                callbackCalled = true;
                savedBytes = bytes;
              },
            ),
          ),
        ),
      );

      // Open fullscreen
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      // Verify we're in fullscreen
      expect(find.text('Firma qui'), findsOneWidget);

      // Tap cancel (X button)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Callback should NOT be called on cancel
      expect(callbackCalled, isFalse);
      expect(savedBytes, isNull);
    });

    testWidgets('fullscreen shows title and buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CieHandSignature(
              readOnly: true,
              fullscreenTitle: 'Test Title',
              fullscreenSaveText: 'Confirm',
            ),
          ),
        ),
      );

      // Open fullscreen
      await tester.tap(find.text('Tocca per firmare'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}

/// Creates a minimal valid PNG image (1x1 transparent pixel).
Uint8List _createMinimalPng() {
  // PNG file signature + minimal IHDR + IDAT + IEND
  return Uint8List.fromList([
    // PNG signature
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    // IHDR chunk (13 bytes data)
    0x00, 0x00, 0x00, 0x0D, // length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    0x00, 0x00, 0x00, 0x01, // width: 1
    0x00, 0x00, 0x00, 0x01, // height: 1
    0x08, // bit depth: 8
    0x06, // color type: RGBA
    0x00, // compression: deflate
    0x00, // filter: adaptive
    0x00, // interlace: none
    0x1F, 0x15, 0xC4, 0x89, // CRC
    // IDAT chunk (minimal compressed data)
    0x00, 0x00, 0x00, 0x0A, // length
    0x49, 0x44, 0x41, 0x54, // "IDAT"
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4, // CRC
    // IEND chunk
    0x00, 0x00, 0x00, 0x00, // length
    0x49, 0x45, 0x4E, 0x44, // "IEND"
    0xAE, 0x42, 0x60, 0x82, // CRC
  ]);
}
