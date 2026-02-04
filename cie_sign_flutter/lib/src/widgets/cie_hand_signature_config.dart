import 'dart:ui';

/// Configuration for the [CieHandSignature] widget.
///
/// This class encapsulates all visual and behavioral settings for the
/// signature pad, including stroke appearance, output dimensions, and
/// path smoothing parameters.
///
/// Example:
/// ```dart
/// const config = CieHandSignatureConfig(
///   strokeColor: Colors.blue,
///   backgroundColor: Colors.white,
///   minStrokeWidth: 1.5,
///   maxStrokeWidth: 5.0,
///   outputWidth: 800,
///   outputHeight: 300,
/// );
/// ```
class CieHandSignatureConfig {
  /// Color of the signature stroke.
  ///
  /// Defaults to black (`Color(0xFF000000)`).
  final Color strokeColor;

  /// Background color of the signature pad.
  ///
  /// Defaults to light gray (`Color(0xFFF5F5F5)`).
  final Color backgroundColor;

  /// Minimum stroke width in logical pixels.
  ///
  /// This is the base width when drawing slowly.
  /// Defaults to `2.0`.
  final double minStrokeWidth;

  /// Maximum stroke width in logical pixels.
  ///
  /// This is the maximum width when drawing quickly (velocity-based).
  /// Defaults to `6.0`.
  final double maxStrokeWidth;

  /// Output image width in pixels for PNG export.
  ///
  /// Defaults to `600`.
  final int outputWidth;

  /// Output image height in pixels for PNG export.
  ///
  /// Defaults to `200`.
  final int outputHeight;

  /// Minimum distance between points to register as a stroke.
  ///
  /// Higher values create smoother but less detailed signatures.
  /// Defaults to `3.0`.
  final double threshold;

  /// Ratio for path smoothing (0.0 - 1.0).
  ///
  /// Higher values create smoother curves.
  /// Defaults to `0.65`.
  final double smoothRatio;

  /// Range for velocity-based stroke width variation.
  ///
  /// Higher values make the stroke width more responsive to drawing speed.
  /// Defaults to `2.0`.
  final double velocityRange;

  /// Whether the output PNG should have a transparent background.
  ///
  /// If `true`, the background will be transparent in the exported PNG.
  /// If `false`, the [backgroundColor] will be used.
  /// Defaults to `true`.
  final bool transparentBackground;

  /// Creates a new signature configuration.
  ///
  /// All parameters have sensible defaults for typical signature capture.
  const CieHandSignatureConfig({
    this.strokeColor = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.minStrokeWidth = 2.0,
    this.maxStrokeWidth = 6.0,
    this.outputWidth = 600,
    this.outputHeight = 200,
    this.threshold = 3.0,
    this.smoothRatio = 0.65,
    this.velocityRange = 2.0,
    this.transparentBackground = true,
  });

  /// Creates a copy of this configuration with the given fields replaced.
  CieHandSignatureConfig copyWith({
    Color? strokeColor,
    Color? backgroundColor,
    double? minStrokeWidth,
    double? maxStrokeWidth,
    int? outputWidth,
    int? outputHeight,
    double? threshold,
    double? smoothRatio,
    double? velocityRange,
    bool? transparentBackground,
  }) {
    return CieHandSignatureConfig(
      strokeColor: strokeColor ?? this.strokeColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      minStrokeWidth: minStrokeWidth ?? this.minStrokeWidth,
      maxStrokeWidth: maxStrokeWidth ?? this.maxStrokeWidth,
      outputWidth: outputWidth ?? this.outputWidth,
      outputHeight: outputHeight ?? this.outputHeight,
      threshold: threshold ?? this.threshold,
      smoothRatio: smoothRatio ?? this.smoothRatio,
      velocityRange: velocityRange ?? this.velocityRange,
      transparentBackground: transparentBackground ?? this.transparentBackground,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CieHandSignatureConfig &&
        other.strokeColor == strokeColor &&
        other.backgroundColor == backgroundColor &&
        other.minStrokeWidth == minStrokeWidth &&
        other.maxStrokeWidth == maxStrokeWidth &&
        other.outputWidth == outputWidth &&
        other.outputHeight == outputHeight &&
        other.threshold == threshold &&
        other.smoothRatio == smoothRatio &&
        other.velocityRange == velocityRange &&
        other.transparentBackground == transparentBackground;
  }

  @override
  int get hashCode {
    return Object.hash(
      strokeColor,
      backgroundColor,
      minStrokeWidth,
      maxStrokeWidth,
      outputWidth,
      outputHeight,
      threshold,
      smoothRatio,
      velocityRange,
      transparentBackground,
    );
  }
}
