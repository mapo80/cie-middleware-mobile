import 'dart:ui';

import 'package:cie_sign_flutter/src/widgets/cie_hand_signature_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CieHandSignatureConfig', () {
    test('has correct default values', () {
      const config = CieHandSignatureConfig();

      expect(config.strokeColor, const Color(0xFF000000));
      expect(config.backgroundColor, const Color(0xFFF5F5F5));
      expect(config.minStrokeWidth, 2.0);
      expect(config.maxStrokeWidth, 6.0);
      expect(config.outputWidth, 600);
      expect(config.outputHeight, 200);
      expect(config.threshold, 3.0);
      expect(config.smoothRatio, 0.65);
      expect(config.velocityRange, 2.0);
      expect(config.transparentBackground, isTrue);
    });

    test('accepts custom values', () {
      const config = CieHandSignatureConfig(
        strokeColor: Color(0xFFFF0000),
        backgroundColor: Color(0xFFFFFFFF),
        minStrokeWidth: 1.0,
        maxStrokeWidth: 10.0,
        outputWidth: 800,
        outputHeight: 400,
        threshold: 5.0,
        smoothRatio: 0.8,
        velocityRange: 3.0,
        transparentBackground: false,
      );

      expect(config.strokeColor, const Color(0xFFFF0000));
      expect(config.backgroundColor, const Color(0xFFFFFFFF));
      expect(config.minStrokeWidth, 1.0);
      expect(config.maxStrokeWidth, 10.0);
      expect(config.outputWidth, 800);
      expect(config.outputHeight, 400);
      expect(config.threshold, 5.0);
      expect(config.smoothRatio, 0.8);
      expect(config.velocityRange, 3.0);
      expect(config.transparentBackground, isFalse);
    });

    group('copyWith', () {
      test('copies with no changes when no parameters provided', () {
        const original = CieHandSignatureConfig(
          strokeColor: Color(0xFFFF0000),
          minStrokeWidth: 3.0,
        );

        final copy = original.copyWith();

        expect(copy.strokeColor, original.strokeColor);
        expect(copy.minStrokeWidth, original.minStrokeWidth);
        expect(copy.backgroundColor, original.backgroundColor);
      });

      test('copies with strokeColor changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(strokeColor: const Color(0xFF0000FF));

        expect(copy.strokeColor, const Color(0xFF0000FF));
        expect(copy.backgroundColor, original.backgroundColor);
      });

      test('copies with backgroundColor changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(backgroundColor: const Color(0xFF00FF00));

        expect(copy.backgroundColor, const Color(0xFF00FF00));
        expect(copy.strokeColor, original.strokeColor);
      });

      test('copies with minStrokeWidth changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(minStrokeWidth: 5.0);

        expect(copy.minStrokeWidth, 5.0);
        expect(copy.maxStrokeWidth, original.maxStrokeWidth);
      });

      test('copies with maxStrokeWidth changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(maxStrokeWidth: 12.0);

        expect(copy.maxStrokeWidth, 12.0);
      });

      test('copies with outputWidth changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(outputWidth: 1000);

        expect(copy.outputWidth, 1000);
      });

      test('copies with outputHeight changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(outputHeight: 500);

        expect(copy.outputHeight, 500);
      });

      test('copies with threshold changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(threshold: 4.0);

        expect(copy.threshold, 4.0);
      });

      test('copies with smoothRatio changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(smoothRatio: 0.9);

        expect(copy.smoothRatio, 0.9);
      });

      test('copies with velocityRange changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(velocityRange: 4.0);

        expect(copy.velocityRange, 4.0);
      });

      test('copies with transparentBackground changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(transparentBackground: false);

        expect(copy.transparentBackground, isFalse);
      });

      test('copies with multiple parameters changed', () {
        const original = CieHandSignatureConfig();
        final copy = original.copyWith(
          strokeColor: const Color(0xFFFF00FF),
          minStrokeWidth: 1.5,
          outputWidth: 1200,
          transparentBackground: false,
        );

        expect(copy.strokeColor, const Color(0xFFFF00FF));
        expect(copy.minStrokeWidth, 1.5);
        expect(copy.outputWidth, 1200);
        expect(copy.transparentBackground, isFalse);
        // Unchanged values
        expect(copy.backgroundColor, original.backgroundColor);
        expect(copy.maxStrokeWidth, original.maxStrokeWidth);
      });
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        const config1 = CieHandSignatureConfig(
          strokeColor: Color(0xFFFF0000),
          minStrokeWidth: 3.0,
        );
        const config2 = CieHandSignatureConfig(
          strokeColor: Color(0xFFFF0000),
          minStrokeWidth: 3.0,
        );

        expect(config1, equals(config2));
      });

      test('two configs with different values are not equal', () {
        const config1 = CieHandSignatureConfig(strokeColor: Color(0xFFFF0000));
        const config2 = CieHandSignatureConfig(strokeColor: Color(0xFF0000FF));

        expect(config1, isNot(equals(config2)));
      });

      test('config equals itself (identity)', () {
        const config = CieHandSignatureConfig();
        expect(config == config, isTrue);
      });

      test('config is not equal to other types', () {
        const config = CieHandSignatureConfig();
        expect(config == 'string', isFalse);
      });

      test('configs with all same fields are equal', () {
        const config1 = CieHandSignatureConfig(
          strokeColor: Color(0xFF123456),
          backgroundColor: Color(0xFFABCDEF),
          minStrokeWidth: 1.5,
          maxStrokeWidth: 7.5,
          outputWidth: 700,
          outputHeight: 300,
          threshold: 4.5,
          smoothRatio: 0.75,
          velocityRange: 2.5,
          transparentBackground: false,
        );
        const config2 = CieHandSignatureConfig(
          strokeColor: Color(0xFF123456),
          backgroundColor: Color(0xFFABCDEF),
          minStrokeWidth: 1.5,
          maxStrokeWidth: 7.5,
          outputWidth: 700,
          outputHeight: 300,
          threshold: 4.5,
          smoothRatio: 0.75,
          velocityRange: 2.5,
          transparentBackground: false,
        );

        expect(config1, equals(config2));
      });
    });

    group('hashCode', () {
      test('equal configs have same hashCode', () {
        const config1 = CieHandSignatureConfig(
          strokeColor: Color(0xFFFF0000),
          minStrokeWidth: 3.0,
        );
        const config2 = CieHandSignatureConfig(
          strokeColor: Color(0xFFFF0000),
          minStrokeWidth: 3.0,
        );

        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different configs typically have different hashCode', () {
        const config1 = CieHandSignatureConfig(strokeColor: Color(0xFFFF0000));
        const config2 = CieHandSignatureConfig(strokeColor: Color(0xFF0000FF));

        // Note: hashCodes can collide, but for these different configs they should differ
        expect(config1.hashCode, isNot(equals(config2.hashCode)));
      });

      test('hashCode is consistent', () {
        const config = CieHandSignatureConfig();
        final hash1 = config.hashCode;
        final hash2 = config.hashCode;

        expect(hash1, equals(hash2));
      });
    });
  });
}
