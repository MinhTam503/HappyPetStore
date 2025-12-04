import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// 3D Model overlay widget for Pet Try-On with 360° rotation support
/// Note: WebView-based 3D models may not capture in screenshots on some platforms
class Model3DOverlay extends StatefulWidget {
  final String modelUrl;
  final Offset offset;
  final double scale;
  final double rotationY; // Primary rotation (0-360 degrees)
  final bool flipHorizontal;
  final bool flipVertical;

  const Model3DOverlay({
    super.key,
    required this.modelUrl,
    required this.offset,
    required this.scale,
    required this.rotationY,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  State<Model3DOverlay> createState() => _Model3DOverlayState();
}

class _Model3DOverlayState extends State<Model3DOverlay> {
  @override
  void initState() {
    super.initState();
    debugPrint('🎭 Model3DOverlay initialized with URL: ${widget.modelUrl}');
  }

  @override
  void didUpdateWidget(Model3DOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) {
      debugPrint('🔄 Model3DOverlay URL changed: ${widget.modelUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modelUrl.isEmpty) {
      debugPrint('⚠️ Model3DOverlay: Empty URL');
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    // Realistic size calculation based on actual pet dimensions
    final clampedScale = widget.scale.clamp(0.1, 5.0);

    // Real-world pet size reference (approximate height in meters at average weight)
    // Dog: 0.5m at 10kg, Cat: 0.25m at 4kg, Fish: 0.15m at 0.5kg, Bird: 0.2m at 0.3kg
    final referenceHeightM = 0.5; // Default for Dog

    // Map screen space: assume 1 meter = 200 pixels on screen for AR-like perspective
    final pixelsPerMeter = 200.0;
    final baseHeightPx =
        referenceHeightM * pixelsPerMeter; // ~100px for reference pet

    // Final size: baseHeight * scale (0.8-2.5 range from weight slider)
    // 1kg dog: 100 * 0.8 * 2.5 = 200px (~0.2m small)
    // 10kg dog: 100 * 1.112 * 2.5 = 278px (~0.28m reasonable)
    // 50kg dog: 100 * 2.5 * 2.5 = 625px (~0.62m large)
    final boxSize = baseHeightPx *
        clampedScale *
        2.5; // Reduced from 5.0 to 2.5 for realistic size

    // Dynamic camera distance: adjusted for smaller models
    // Small pets (0.8 scale) = 6.0m away, Large pets (2.5 scale) = 2.0m away
    final cameraDistance = (5.0 / clampedScale).clamp(2.0, 6.0);
    final cameraOrbit = '0deg 75deg ${cameraDistance.toStringAsFixed(2)}m';
    const fovDeg = 45.0;

    debugPrint('📐 Model3DOverlay rendering:');
    debugPrint('   Screen: ${screenSize.width} x ${screenSize.height}');
    debugPrint('   Offset: ${widget.offset}');
    debugPrint('   Scale: ${widget.scale}');
    debugPrint('   BoxSize: ${boxSize.toStringAsFixed(1)} px');
    debugPrint('   Camera Distance: ${cameraDistance.toStringAsFixed(2)}m');
    debugPrint('   Camera Orbit: $cameraOrbit');
    debugPrint('   FOV: ${fovDeg.toStringAsFixed(1)}°');
    debugPrint('   Rotation Y: ${widget.rotationY}°');

    // Apply transformations: position, flip, and zoom
    final scaleX = widget.flipHorizontal ? -1.0 : 1.0;
    final scaleY = widget.flipVertical ? -1.0 : 1.0;

    return Center(
        child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        // First translate to move the viewer around screen
        ..translate(widget.offset.dx, widget.offset.dy)
        // Then apply flip
        ..scale(scaleX, scaleY, 1.0),
      child: RepaintBoundary(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Container(
            width: boxSize,
            height: boxSize,
            child: ModelViewer(
              src: widget.modelUrl,
              alt: "3D Pet Model",
              ar: true,
              arModes: const ['scene-viewer', 'webxr', 'quick-look'],
              iosSrc: widget.modelUrl,
              autoRotate: false,

              // Enable camera controls for 360° rotation and zoom
              cameraControls: true,
              disableZoom: false,
              touchAction: TouchAction.panY,

              // CRITICAL: Disable auto-framing to prevent auto-zoom on load
              disableTap: true,

              // Camera position - only distance changes with scale
              cameraOrbit: cameraOrbit,
              fieldOfView: '${fovDeg.toStringAsFixed(1)}deg',
              minFieldOfView: '15deg',
              maxFieldOfView: '90deg',

              // Lock camera target to prevent auto-framing
              cameraTarget: '0m 0m 0m',

              // CRITICAL: Minimize auto-animation that causes size changes
              // Must be > 0, use very small value for instant camera updates
              interpolationDecay: 100,

              // Rotation control via orientation
              orientation: '0deg ${widget.rotationY}deg 0deg',

              // Lighting
              shadowIntensity: 0.0,
              shadowSoftness: 0.0,
              exposure: 1.5,

              // Performance
              loading: Loading.eager,

              // Transparent background
              backgroundColor: Colors.transparent,

              // Interaction prompt
              interactionPrompt: InteractionPrompt.auto,
              interactionPromptThreshold: 1000,
              interactionPromptStyle: InteractionPromptStyle.basic,

              // No environment
              environmentImage: null,
              skyboxImage: null,

              // No poster
              poster: null,

              // Force transparency via CSS with WebGL fixes and touch optimization
              relatedCss: '''
              body, html {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                background: transparent !important;
                background-color: transparent !important;
                overflow: hidden;
                touch-action: pan-y pinch-zoom;
                -webkit-user-select: none;
                user-select: none;
              }
              model-viewer {
                width: 100%;
                height: 100%;
                background: transparent !important;
                background-color: transparent !important;
                --poster-color: transparent !important;
                --progress-bar-color: transparent;
                touch-action: pan-y pinch-zoom;
              }
              model-viewer::part(default-progress-bar) {
                display: none;
              }
              canvas {
                image-rendering: -webkit-optimize-contrast;
                image-rendering: crisp-edges;
                touch-action: pan-y pinch-zoom;
              }
            ''',

              // JavaScript to prevent auto-framing and lock camera
              relatedJs: '''
              const modelViewer = document.querySelector('model-viewer');
              
              // Prevent auto-framing on load by locking camera immediately
              modelViewer.addEventListener('load', () => {
                // Re-apply camera orbit after model loads to prevent auto-zoom
                modelViewer.cameraOrbit = '$cameraOrbit';
                modelViewer.fieldOfView = '${fovDeg.toStringAsFixed(1)}deg';
                modelViewer.cameraTarget = '0m 0m 0m';
              });
              
              // Lock camera position immediately to prevent initial auto-zoom
              modelViewer.cameraOrbit = '$cameraOrbit';
              modelViewer.fieldOfView = '${fovDeg.toStringAsFixed(1)}deg';
              modelViewer.cameraTarget = '0m 0m 0m';
              ''',
            ),
          ),
        ),
      ),
    ));
  }
}
