import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

import 'cie_hand_signature_config.dart';

/// Controller for managing [CieHandSignature] widget state.
///
/// This controller allows external management of the signature pad,
/// including clearing, checking state, and exporting to PNG.
///
/// Example:
/// ```dart
/// final controller = CieHandSignatureController();
///
/// // Later, check if signature exists
/// if (controller.isFilled) {
///   final pngBytes = await controller.toPngBytes();
///   // Use the signature image...
/// }
///
/// // Clear the signature
/// controller.clear();
///
/// // Don't forget to dispose
/// controller.dispose();
/// ```
class CieHandSignatureController extends ChangeNotifier {
  late final HandSignatureControl _internal;
  CieHandSignatureConfig _config;
  bool _disposed = false;

  /// Initial image to display (used in fullscreen mode).
  /// This image is shown as background until user starts drawing.
  Uint8List? _initialImage;

  /// Whether the user has drawn something (as opposed to just viewing initialImage).
  bool _hasDrawn = false;

  /// Whether the user has cleared the signature (without drawing new content).
  bool _wasCleared = false;

  /// Creates a new signature controller with optional configuration and initial image.
  ///
  /// [initialImage] - PNG bytes of an existing signature to display.
  /// Used in fullscreen mode to show the current signature for editing.
  CieHandSignatureController({
    CieHandSignatureConfig config = const CieHandSignatureConfig(),
    Uint8List? initialImage,
  })  : _config = config,
        _initialImage = initialImage {
    _internal = HandSignatureControl(
      initialSetup: SignaturePathSetup(
        threshold: config.threshold,
        smoothRatio: config.smoothRatio,
        velocityRange: config.velocityRange,
        pressureRatio: 0.0,
      ),
    );
    _internal.addListener(_onInternalChanged);
  }

  /// The internal hand signature control.
  ///
  /// This is exposed for advanced use cases but should generally not be
  /// accessed directly.
  HandSignatureControl get internal => _internal;

  /// The current configuration.
  CieHandSignatureConfig get config => _config;

  /// Updates the configuration.
  ///
  /// Note: Some settings (like threshold, smoothRatio) only affect new strokes.
  set config(CieHandSignatureConfig value) {
    if (_config != value) {
      _config = value;
      notifyListeners();
    }
  }

  /// The initial image passed to the controller (if any).
  Uint8List? get initialImage => _initialImage;

  /// Whether the user has drawn something new (not just viewing initialImage).
  bool get hasDrawn => _hasDrawn;

  /// Whether the user has cleared the signature without drawing new content.
  bool get wasCleared => _wasCleared;

  /// Whether the signature pad contains any strokes or has an initial image.
  bool get isFilled => _internal.isFilled || (_initialImage != null && !_wasCleared);

  /// Whether there is drawable content (strokes on the pad).
  bool get hasStrokes => _internal.isFilled;

  /// Whether the signature pad is currently empty (no strokes and no initial image).
  bool get isEmpty => !_internal.isFilled && (_initialImage == null || _wasCleared);

  /// Clears all strokes from the signature pad.
  /// Also marks the controller as "cleared" for save/cancel logic.
  void clear() {
    if (_disposed) return;
    _internal.clear();
    _wasCleared = true;
    _hasDrawn = false;
    notifyListeners();
  }

  /// Exports the current signature as PNG bytes.
  ///
  /// Returns `null` if the signature pad is empty or if the controller
  /// has been disposed.
  ///
  /// Uses the configuration's [CieHandSignatureConfig.outputWidth],
  /// [CieHandSignatureConfig.outputHeight], and color settings.
  Future<Uint8List?> toPngBytes() async {
    if (_disposed || !isFilled) return null;

    try {
      final byteData = await _internal.toImage(
        width: _config.outputWidth,
        height: _config.outputHeight,
        format: ui.ImageByteFormat.png,
        background:
            _config.transparentBackground ? Colors.transparent : _config.backgroundColor,
        color: _config.strokeColor,
        fit: true,
      );

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  void _onInternalChanged() {
    if (!_disposed) {
      // Track if user has started drawing
      if (_internal.isFilled && !_hasDrawn) {
        _hasDrawn = true;
        _wasCleared = false; // Drawing after clear = new content
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _internal.removeListener(_onInternalChanged);
    _internal.dispose();
    super.dispose();
  }
}
