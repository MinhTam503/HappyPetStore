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

    // Convert offset from center-based positioning
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    
    // Base size 300px for better visibility
    final baseSize = 300.0;
    final modelSize = baseSize * widget.scale;
    
    // Calculate position (offset is from center)
    final left = centerX + widget.offset.dx - (modelSize / 2);
    final top = centerY + widget.offset.dy - (modelSize / 2);

    debugPrint('📐 Model3DOverlay rendering:');
    debugPrint('   Screen: ${screenSize.width} x ${screenSize.height}');
    debugPrint('   Position: left=$left, top=$top');
    debugPrint('   Size: $modelSize x $modelSize');
    debugPrint('   Rotation: ${widget.rotationY}°');

    // Apply flip transformations
    final scaleX = widget.flipHorizontal ? -1.0 : 1.0;
    final scaleY = widget.flipVertical ? -1.0 : 1.0;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: modelSize,
          height: modelSize,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(scaleX, scaleY, 1.0),
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: ModelViewer(
                  src: widget.modelUrl,
                  alt: "3D Pet Model",
                  ar: true, // Enable AR mode for iOS devices
                  arModes: const ['scene-viewer', 'webxr', 'quick-look'], // Support multiple AR modes
                  iosSrc: widget.modelUrl, // Use same model for iOS AR Quick Look
                  autoRotate: false,
                  // Enable camera controls for 360° rotation and zoom
                  cameraControls: true,
                  disableZoom: false,
                  touchAction: TouchAction.panY,
                  
                  // Camera configuration - optimal view
                  cameraOrbit: '0deg 75deg 2.5m',
                  fieldOfView: '30deg',
                  minFieldOfView: '25deg',
                  maxFieldOfView: '45deg',
                  
                  // Rotation control via orientation
                  orientation: '0deg ${widget.rotationY}deg 0deg',
                  
                  // Lighting
                  shadowIntensity: 0.0,
                  shadowSoftness: 0.0,
                  exposure: 1.5, // Brighter
                  
                  // Performance
                  loading: Loading.eager,
                  
                  // Transparent background
                  backgroundColor: Colors.transparent,
                  
                  // Interaction prompt for users on real devices
                  interactionPrompt: InteractionPrompt.auto,
                  interactionPromptThreshold: 1000, // Show prompt after 1 second
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
                      touch-action: pan-y pinch-zoom; /* Enable touch gestures on real devices */
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
                      touch-action: pan-y pinch-zoom; /* Critical for iOS touch */
                    }
                    model-viewer::part(default-progress-bar) {
                      display: none;
                    }
                    canvas {
                      image-rendering: -webkit-optimize-contrast;
                      image-rendering: crisp-edges;
                      touch-action: pan-y pinch-zoom; /* Enable canvas touch gestures */
                    }
                  ''',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
