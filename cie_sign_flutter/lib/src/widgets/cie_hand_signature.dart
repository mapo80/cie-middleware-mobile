import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_signature/signature.dart';

import 'cie_hand_signature_config.dart';
import 'cie_hand_signature_controller.dart';

/// Orientation preference for fullscreen signature mode.
enum SignatureOrientation {
  /// Portrait orientation (vertical).
  portrait,

  /// Landscape orientation (horizontal).
  landscape,

  /// Auto-detect based on device orientation.
  auto,
}

/// A hand signature capture widget for the CIE Sign SDK.
///
/// This widget provides an intuitive touch-based signature pad with
/// built-in controls for clearing and saving. It supports both inline
/// and fullscreen modes.
///
/// ## Read-Only Mode (default)
///
/// By default, the widget displays the signature in read-only mode.
/// Users must open fullscreen to edit the signature.
///
/// ```dart
/// CieHandSignature(
///   signatureImage: _signatureBytes,
///   readOnly: true,
///   onSignatureSaved: (bytes) {
///     setState(() => _signatureBytes = bytes);
///   },
/// )
/// ```
///
/// ## Drawing Mode
///
/// Set `readOnly: false` to allow direct drawing on the widget.
///
/// ```dart
/// CieHandSignature(
///   readOnly: false,
///   onSignatureSaved: (bytes) => saveSignature(bytes),
///   onSignatureCleared: () => clearSignature(),
/// )
/// ```
///
/// ## Fullscreen Mode
///
/// ```dart
/// final bytes = await CieHandSignature.openFullscreen(
///   context,
///   initialImage: _currentSignature,
///   orientation: SignatureOrientation.landscape,
/// );
///
/// if (bytes != null) {
///   // User saved signature
///   setState(() => _signatureBytes = bytes);
/// }
/// ```
class CieHandSignature extends StatefulWidget {
  /// Configuration for visual appearance and export settings.
  final CieHandSignatureConfig config;

  /// Current signature image (PNG bytes).
  ///
  /// When [readOnly] is true, this image is displayed.
  /// When opening fullscreen, this image is passed as the initial content.
  final Uint8List? signatureImage;

  /// Whether the widget is in read-only mode.
  ///
  /// When true (default), the signature image is displayed but cannot be edited.
  /// Users must open fullscreen to modify the signature.
  ///
  /// When false, users can draw directly on the widget.
  final bool readOnly;

  /// Optional external controller for managing the signature pad.
  ///
  /// Only used when [readOnly] is false.
  /// If not provided, an internal controller will be created.
  final CieHandSignatureController? controller;

  /// Whether to show built-in buttons.
  ///
  /// Defaults to `true`.
  final bool showButtons;

  /// Text for the clear button (only shown when readOnly is false).
  ///
  /// Defaults to `'Pulisci'`.
  final String clearButtonText;

  /// Text for the save button (only shown when readOnly is false).
  ///
  /// Defaults to `'Salva'`.
  final String saveButtonText;

  /// Whether to show the fullscreen button.
  ///
  /// Defaults to `true`.
  final bool showFullscreenButton;

  /// Tooltip for the fullscreen button.
  final String? fullscreenTooltip;

  /// Orientation for fullscreen mode.
  ///
  /// Defaults to [SignatureOrientation.auto].
  final SignatureOrientation fullscreenOrientation;

  /// Title for the fullscreen dialog.
  ///
  /// Defaults to `'Firma qui'`.
  final String fullscreenTitle;

  /// Save button text for fullscreen dialog.
  ///
  /// Defaults to `'Salva'`.
  final String fullscreenSaveText;

  /// Cancel button text for fullscreen dialog.
  ///
  /// Defaults to `'Annulla'`.
  final String fullscreenCancelText;

  /// Callback when the user saves the signature.
  ///
  /// Called both from inline save button (when readOnly is false)
  /// and from fullscreen save.
  final void Function(Uint8List pngBytes)? onSignatureSaved;

  /// Callback when the signature is cleared.
  ///
  /// Only called when readOnly is false and user clears the signature.
  final VoidCallback? onSignatureCleared;

  /// Callback when the signature state changes (filled/empty).
  ///
  /// Only called when readOnly is false.
  final void Function(bool isFilled)? onSignatureChanged;

  /// Aspect ratio of the signature pad.
  ///
  /// Defaults to `3.0` (width:height = 3:1).
  final double aspectRatio;

  /// Border radius for the signature pad container.
  final BorderRadius? borderRadius;

  /// Optional decoration for the signature pad container.
  ///
  /// If not provided, a default decoration with light gray background
  /// and border will be used.
  final BoxDecoration? decoration;

  /// Widget to display when there is no signature (in readOnly mode).
  ///
  /// If not provided, a default placeholder with icon and text is shown.
  final Widget? emptyPlaceholder;

  /// Creates a new hand signature widget.
  const CieHandSignature({
    super.key,
    this.config = const CieHandSignatureConfig(),
    this.signatureImage,
    this.readOnly = true,
    this.controller,
    this.showButtons = true,
    this.clearButtonText = 'Pulisci',
    this.saveButtonText = 'Salva',
    this.showFullscreenButton = true,
    this.fullscreenTooltip,
    this.fullscreenOrientation = SignatureOrientation.auto,
    this.fullscreenTitle = 'Firma qui',
    this.fullscreenSaveText = 'Salva',
    this.fullscreenCancelText = 'Annulla',
    this.onSignatureSaved,
    this.onSignatureCleared,
    this.onSignatureChanged,
    this.aspectRatio = 3.0,
    this.borderRadius,
    this.decoration,
    this.emptyPlaceholder,
  });

  /// Opens a fullscreen signature capture dialog.
  ///
  /// Returns the signature PNG bytes if the user saves, or `null` if cancelled.
  ///
  /// [initialImage] - Existing signature to display for editing.
  /// [orientation] - Preferred screen orientation.
  /// [title] - Dialog title.
  /// [saveButtonText] - Text for save button.
  /// [cancelButtonText] - Text for cancel button.
  ///
  /// The fullscreen editor uses a local controller. Changes are only applied
  /// when the user taps save. If cancelled, the original image is preserved.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await CieHandSignature.openFullscreen(
  ///   context,
  ///   initialImage: _currentSignature,
  ///   orientation: SignatureOrientation.landscape,
  /// );
  ///
  /// if (bytes != null) {
  ///   setState(() => _signatureBytes = bytes);
  /// }
  /// ```
  static Future<Uint8List?> openFullscreen(
    BuildContext context, {
    Uint8List? initialImage,
    CieHandSignatureConfig config = const CieHandSignatureConfig(),
    SignatureOrientation orientation = SignatureOrientation.auto,
    String title = 'Firma qui',
    String saveButtonText = 'Salva',
    String cancelButtonText = 'Annulla',
  }) async {
    // Determine target orientations
    final List<DeviceOrientation> targetOrientations;
    switch (orientation) {
      case SignatureOrientation.landscape:
        targetOrientations = [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
        break;
      case SignatureOrientation.portrait:
        targetOrientations = [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
        break;
      case SignatureOrientation.auto:
        targetOrientations = [];
        break;
    }

    // Get navigator before async operations
    final navigator = Navigator.of(context);

    // Lock orientation if requested
    if (targetOrientations.isNotEmpty) {
      await SystemChrome.setPreferredOrientations(targetOrientations);
    }

    try {
      // Show fullscreen page
      final result = await navigator.push<Uint8List?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => _FullscreenSignaturePage(
            initialImage: initialImage,
            config: config,
            title: title,
            saveButtonText: saveButtonText,
            cancelButtonText: cancelButtonText,
          ),
        ),
      );
      return result;
    } finally {
      // Restore all orientations
      if (targetOrientations.isNotEmpty) {
        await SystemChrome.setPreferredOrientations([]);
      }
    }
  }

  @override
  State<CieHandSignature> createState() => _CieHandSignatureState();
}

class _CieHandSignatureState extends State<CieHandSignature> {
  CieHandSignatureController? _internalController;
  bool _lastFilledState = false;

  CieHandSignatureController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      _initController();
    }
  }

  void _initController() {
    if (widget.controller == null) {
      _internalController = CieHandSignatureController(config: widget.config);
    } else {
      widget.controller!.config = widget.config;
    }
    _controller.addListener(_onControllerChanged);
    _lastFilledState = _controller.isFilled;
  }

  @override
  void didUpdateWidget(CieHandSignature oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle transition between readOnly modes
    if (widget.readOnly != oldWidget.readOnly) {
      if (widget.readOnly) {
        // Switching to readOnly - dispose controller
        _internalController?.removeListener(_onControllerChanged);
        _internalController?.dispose();
        _internalController = null;
      } else {
        // Switching to drawing mode - init controller
        _initController();
      }
    }

    // Handle controller change (only relevant when not readOnly)
    if (!widget.readOnly && widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _internalController?.removeListener(_onControllerChanged);

      if (widget.controller == null && _internalController == null) {
        _internalController = CieHandSignatureController(config: widget.config);
      } else if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      }

      _controller.addListener(_onControllerChanged);
    }

    // Update config
    if (!widget.readOnly && widget.config != oldWidget.config) {
      _controller.config = widget.config;
    }
  }

  void _onControllerChanged() {
    final currentFilled = _controller.isFilled;
    if (currentFilled != _lastFilledState) {
      _lastFilledState = currentFilled;
      widget.onSignatureChanged?.call(currentFilled);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleSave() async {
    final bytes = await _controller.toPngBytes();
    if (bytes != null) {
      widget.onSignatureSaved?.call(bytes);
    }
  }

  void _handleClear() {
    _controller.clear();
    widget.onSignatureCleared?.call();
  }

  Future<void> _openFullscreen() async {
    final bytes = await CieHandSignature.openFullscreen(
      context,
      initialImage: widget.signatureImage,
      config: widget.config,
      orientation: widget.fullscreenOrientation,
      title: widget.fullscreenTitle,
      saveButtonText: widget.fullscreenSaveText,
      cancelButtonText: widget.fullscreenCancelText,
    );
    if (bytes != null) {
      widget.onSignatureSaved?.call(bytes);
    }
  }

  @override
  void dispose() {
    if (!widget.readOnly) {
      _controller.removeListener(_onControllerChanged);
    }
    _internalController?.dispose();
    super.dispose();
  }

  BoxDecoration get _defaultDecoration => BoxDecoration(
        color: widget.config.backgroundColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      );

  Widget _buildReadOnlyView() {
    if (widget.signatureImage != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        child: Image.memory(
          widget.signatureImage!,
          fit: BoxFit.contain,
        ),
      );
    }
    return widget.emptyPlaceholder ?? _buildDefaultPlaceholder();
  }

  Widget _buildDefaultPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.draw_outlined,
            size: 32,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            'Tocca per firmare',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingPad() {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      child: HandSignature(
        control: _controller.internal,
        color: widget.config.strokeColor,
        width: widget.config.minStrokeWidth,
        maxWidth: widget.config.maxStrokeWidth,
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        // Clear button (only in drawing mode)
        if (!widget.readOnly)
          TextButton(
            onPressed: _controller.isFilled ? _handleClear : null,
            child: Text(widget.clearButtonText),
          ),
        const Spacer(),
        // Fullscreen button
        if (widget.showFullscreenButton)
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: widget.fullscreenTooltip ?? 'Apri a tutto schermo',
            onPressed: _openFullscreen,
          ),
        // Save button (only in drawing mode)
        if (!widget.readOnly)
          ElevatedButton(
            onPressed: _controller.isFilled ? _handleSave : null,
            child: Text(widget.saveButtonText),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          // In readOnly mode, tap opens fullscreen
          onTap: widget.readOnly && widget.showFullscreenButton
              ? _openFullscreen
              : null,
          // Block parent scroll when drawing (only in drawing mode)
          onVerticalDragStart: widget.readOnly ? null : (_) {},
          onVerticalDragUpdate: widget.readOnly ? null : (_) {},
          onHorizontalDragStart: widget.readOnly ? null : (_) {},
          onHorizontalDragUpdate: widget.readOnly ? null : (_) {},
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: DecoratedBox(
              decoration: widget.decoration ?? _defaultDecoration,
              child: widget.readOnly ? _buildReadOnlyView() : _buildDrawingPad(),
            ),
          ),
        ),
        if (widget.showButtons) ...[
          const SizedBox(height: 8),
          _buildButtons(),
        ],
      ],
    );
  }
}

/// Fullscreen signature capture page.
///
/// Uses a local controller for editing. Changes are only committed when
/// the user taps save. Cancelling discards all changes.
class _FullscreenSignaturePage extends StatefulWidget {
  final Uint8List? initialImage;
  final CieHandSignatureConfig config;
  final String title;
  final String saveButtonText;
  final String cancelButtonText;

  const _FullscreenSignaturePage({
    required this.initialImage,
    required this.config,
    required this.title,
    required this.saveButtonText,
    required this.cancelButtonText,
  });

  @override
  State<_FullscreenSignaturePage> createState() =>
      _FullscreenSignaturePageState();
}

class _FullscreenSignaturePageState extends State<_FullscreenSignaturePage> {
  late final CieHandSignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CieHandSignatureController(
      config: widget.config,
      initialImage: widget.initialImage,
    );
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSave() async {
    Uint8List? result;

    if (_controller.hasDrawn) {
      // User has drawn something new → export the drawing
      result = await _controller.toPngBytes();
    } else if (_controller.wasCleared) {
      // User only cleared without drawing → save as cleared (null signature)
      // We use an empty Uint8List to distinguish from "cancelled"
      result = Uint8List(0);
    } else {
      // No changes → return original image
      result = widget.initialImage;
    }

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _handleCancel() {
    // Discard all changes, return null to indicate cancellation
    Navigator.of(context).pop(null);
  }

  void _handleClear() {
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Whether there is content to display (drawing, initial image, or neither cleared)
  bool get _hasContent =>
      _controller.hasStrokes ||
      (widget.initialImage != null && !_controller.wasCleared);

  /// Whether save should be enabled
  bool get _canSave =>
      _controller.hasDrawn ||
      _controller.wasCleared ||
      widget.initialImage != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _handleCancel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _hasContent ? _handleClear : null,
            tooltip: 'Pulisci',
          ),
          TextButton(
            onPressed: _canSave ? _handleSave : null,
            child: Text(
              widget.saveButtonText,
              style: TextStyle(
                color: _canSave
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 800,
                maxHeight: 400,
              ),
              child: AspectRatio(
                aspectRatio: 3.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.config.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Show initial image as background if present and not cleared/drawn over
                        if (widget.initialImage != null &&
                            !_controller.hasDrawn &&
                            !_controller.wasCleared)
                          Positioned.fill(
                            child: Image.memory(
                              widget.initialImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        // Drawing area on top
                        Positioned.fill(
                          child: HandSignature(
                            control: _controller.internal,
                            color: widget.config.strokeColor,
                            width: widget.config.minStrokeWidth,
                            maxWidth: widget.config.maxStrokeWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
