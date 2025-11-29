import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/core/utils/notification_helper.dart';
import 'package:pet_shop/presentation/widgets/model_3d_overlay.dart';

/// Pet Try-On MVP with collapsible controls and weight-based sizing
/// Fixed camera disposal crash on Android/iOS
class PetTryOnPage extends StatefulWidget {
  final Map<String, dynamic> pet;
  const PetTryOnPage({super.key, required this.pet});

  @override
  State<PetTryOnPage> createState() => _PetTryOnPageState();
}

class _PetTryOnPageState extends State<PetTryOnPage> with WidgetsBindingObserver {
  final GlobalKey _captureKey = GlobalKey();
  CameraController? _cameraController;
  bool _useLiveCamera = true;
  bool _cameraInitializing = false;
  XFile? _roomPhoto;
  String? _error;
  bool _hintVisible = true;

  // Collapsible controls
  bool _controlsExpanded = true;

  // Sticker transform
  Offset _stickerOffset = const Offset(0, 0);
  double _stickerScale = 0.3;
  double _stickerRotation = 0.0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Gesture base values
  Offset _baseOffset = const Offset(0, 0);
  double _baseScale = 0.3;
  double _baseRotation = 0.0;

  // Weight-based sizing
  double _petWeightKg = 10.0;
  
  // 3D capture flag
  bool _isCapturing3D = false;
  
  final Map<String, Map<String, double>> _categoryWeightRanges = {
    'Dog': {'min': 1.0, 'max': 50.0, 'default': 10.0},
    'Cat': {'min': 1.0, 'max': 10.0, 'default': 4.0},
    'Fish': {'min': 0.1, 'max': 5.0, 'default': 0.5},
    'Bird': {'min': 0.05, 'max': 2.0, 'default': 0.3},
  };

  // Category selection + dynamic image handling
  String _selectedCategory = 'Dog';
  final List<String> _categories = ['Dog', 'Cat', 'Fish', 'Bird'];
  final Map<String, String> _categoryImageUrls = {}; // Fetched download URLs (2D)
  final Map<String, String> _categoryModelUrls = {}; // Fetched download URLs (3D)
  final Set<String> _categoryLoading = {}; // Loading state per category
  bool _use3DMode = false; // Toggle between 2D images and 3D models
  final Map<String, String> _categoryFolderNames = {
    'Dog': 'Dogs',
    'Cat': 'Cats',
    'Fish': 'Fish',
    'Bird': 'Birds',
  };
  
  final Map<String, String> _category3DFolderNames = {
    'Dog': 'Dogs_3D',
    'Cat': 'Cats_3D',
    'Fish': 'Fish_3D',
    'Bird': 'Birds_3D',
  };

  final Map<String, IconData> _categoryIcons = {
    'Dog': Icons.pets,
    'Cat': Icons.pest_control,
    'Fish': Icons.phishing,
    'Bird': Icons.flutter_dash,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePetCategory();
    _initCameraIfNeeded();
  }

  void _initializePetCategory() {
    final petType = (widget.pet['type'] ?? widget.pet['category'] ?? 'Dog').toString().toLowerCase();
    if (petType.contains('dog') || petType.contains('chó')) {
      _selectedCategory = 'Dog';
    } else if (petType.contains('cat') || petType.contains('mèo')) {
      _selectedCategory = 'Cat';
    } else if (petType.contains('fish') || petType.contains('cá')) {
      _selectedCategory = 'Fish';
    } else if (petType.contains('bird') || petType.contains('chim')) {
      _selectedCategory = 'Bird';
    }
    _petWeightKg = _categoryWeightRanges[_selectedCategory]!['default']!;
    _updateScaleFromWeight();
    _ensureCategoryImageLoaded(_selectedCategory);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose camera controller safely to avoid crash
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle to prevent camera crashes
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Pause camera when app goes to background
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app comes back
      if (_useLiveCamera && mounted) {
        _initCameraIfNeeded();
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController?.dispose();
        _cameraController = null;
      } catch (e) {
        // Ignore camera disposal errors
        debugPrint('Camera disposal error (safe to ignore): $e');
      }
    }
  }

  Future<void> _initCameraIfNeeded() async {
    if (!_useLiveCamera) return;
    
    // Dispose existing controller first
    if (_cameraController != null) {
      await _disposeCamera();
    }
    
    setState(() {
      _cameraInitializing = true;
      _error = null;
    });
    
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      
      _cameraController =
          CameraController(back, ResolutionPreset.medium, enableAudio: false);
      
      await _cameraController!.initialize();
      
      if (!mounted) {
        await _disposeCamera();
        return;
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _error = l10n.cameraInitError(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
        });
      }
    }
  }

  Future<void> _pickRoomPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // Dispose old camera first
      await _disposeCamera();
      setState(() {
        _roomPhoto = photo;
        _useLiveCamera = false;
      });
    }
  }

  void _switchMode(bool live) async {
    if (live == _useLiveCamera) return;
    
    // Dispose camera before switching modes
    if (!live) {
      await _disposeCamera();
    }
    
    setState(() {
      _useLiveCamera = live;
      _error = null;
    });
    
    if (live) {
      await _initCameraIfNeeded();
    }
  }

  Future<void> _captureScreenshot() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Warning for 3D mode screenshot limitations
    if (_use3DMode && mounted) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Chụp ảnh 3D'),
            ],
          ),
          content: const Text(
            'Lưu ý: Mô hình 3D có thể không hiển thị đầy đủ trong ảnh chụp do giới hạn kỹ thuật WebView.\n\n'
            'Để có ảnh đẹp hơn:\n'
            '• Chuyển sang chế độ 2D\n'
            '• Hoặc dùng screenshot hệ thống\n'
            '• Hoặc dùng AR mode và chụp bằng camera thông thường',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vẫn chụp'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }
    
    try {
      DialogHelper.showLoadingDialog(context);
      
      // Special handling for 3D mode: wait for WebView to render
      if (_use3DMode) {
        setState(() => _isCapturing3D = true);
        // Give WebView time to render to texture
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // Higher pixel ratio for 3D to capture more detail
      final pixelRatio = _use3DMode ? 4.0 : 3.0;
      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (_use3DMode) {
        setState(() => _isCapturing3D = false);
      }
      
      if (byteData == null) {
        throw Exception('Failed to capture image data');
      }
      
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'pet_try_on_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Save to gallery using gal package
      await Gal.putImageBytes(pngBytes, album: 'PetTryOn');
       
      if (mounted) {
        NotificationHelper.showSuccess(context, l10n.photoSaved(fileName));
      }

      await Share.shareXFiles([XFile(file.path)], text: l10n.shareText);
    } catch (e) {
      debugPrint('❌ Screenshot error: $e');
      if (mounted) {
        NotificationHelper.showError(context, l10n.captureError(e.toString()));
      }
    } finally {
      if (_use3DMode && _isCapturing3D) {
        setState(() => _isCapturing3D = false);
      }
      await DialogHelper.safeHideLoadingDialog();
    }
  }

  void _onScaleStart(ScaleStartDetails details, Size canvasSize) {
    _baseOffset = _stickerOffset;
    _baseScale = _stickerScale;
    _baseRotation = _stickerRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    // Both 2D and 3D: 1-finger = move widget position, 2-finger = scale widget size
    // 3D model's internal rotation/zoom is handled by ModelViewer cameraControls
    final isSingleFinger = details.pointerCount == 1;
    
    double newScale = _stickerScale;
    double newRotation = _stickerRotation;
    Offset newOffset = _stickerOffset;

    if (isSingleFinger) {
      // 1 finger: move widget position (both 2D and 3D)
      final delta = details.focalPointDelta;
      newOffset = _stickerOffset + delta;
    } else {
      // 2+ fingers: scale widget size + move
      newScale = (_baseScale * details.scale).clamp(0.05, 5.0);
      
      // Only apply rotation for 2D mode (3D uses ModelViewer cameraControls)
      if (!_use3DMode) {
        newRotation = _baseRotation + details.rotation;
      }
      
      final delta = details.focalPointDelta;
      newOffset = _baseOffset + delta;
    }

    // Keep within bounds with margin
    final margin = 20.0;
    final halfWidth = (canvasSize.width * newScale) / 2;
    final halfHeight = (canvasSize.height * newScale) / 2;
    final maxOffsetX = (canvasSize.width / 2) - halfWidth + margin;
    final maxOffsetY = (canvasSize.height / 2) - halfHeight + margin;
    
    newOffset = Offset(
      newOffset.dx.clamp(-maxOffsetX, maxOffsetX),
      newOffset.dy.clamp(-maxOffsetY, maxOffsetY),
    );

    setState(() {
      _stickerScale = newScale;
      _stickerRotation = newRotation;
      _stickerOffset = newOffset;
    });
  }

  void _updateScaleFromWeight() {
    final range = _categoryWeightRanges[_selectedCategory]!;
    final normalized = (_petWeightKg - range['min']!) / (range['max']! - range['min']!);
    // Scale range 0.3 to 1.2 for better visibility (baseSize now 300px)
    final newScale = 0.3 + (normalized * 0.9);
    setState(() {
      _stickerScale = newScale;
      _baseScale = newScale;
    });
  }

  void _onWeightChanged(double weight) {
    setState(() {
      _petWeightKg = weight;
    });
    _updateScaleFromWeight();
  }

  void _changePetCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _petWeightKg = _categoryWeightRanges[category]!['default']!;
    });
    _updateScaleFromWeight();
    _ensureCategoryImageLoaded(category);
  }

  void _ensureCategoryImageLoaded(String category) {
    if (_categoryImageUrls.containsKey(category) || _categoryLoading.contains(category)) return;
    _categoryLoading.add(category);
    final folder = _categoryFolderNames[category] ?? category;
    final folder3D = _category3DFolderNames[category] ?? '${category}_3D';
    
    // Show loading only when fetching current category image for first time
    final shouldShowOverlay = category == _selectedCategory;
    if (shouldShowOverlay && mounted) {
      // Defer showing dialog until after current build frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryLoading.contains(category)) {
          DialogHelper.showLoadingDialog(context);
        }
      });
    }
    
    // Load both 2D image and 3D model in parallel
    Future.wait([
      _fetchFirstImageInFolder('3d_model/$folder'),
      _fetchFirst3DModelInFolder('3d_model/$folder3D'),
    ]).then((urls) {
      if (!mounted) return;
      setState(() {
        if (urls[0] != null) {
          _categoryImageUrls[category] = urls[0]!;
        }
        if (urls[1] != null) {
          _categoryModelUrls[category] = urls[1]!;
        }
        _categoryLoading.remove(category);
      });
      if (shouldShowOverlay) {
        DialogHelper.safeHideLoadingDialog();
      }
    });
  }

  Future<String?> _fetchFirstImageInFolder(String path) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      final result = await ref.listAll();
      if (result.items.isEmpty) {
        debugPrint('No images found in storage path: $path');
        return null;
      }
      Reference? selected;
      for (final item in result.items) {
        final name = item.name.toLowerCase();
        if (name.endsWith('.png')) {
          selected = item;
          break;
        }
      }
      selected ??= result.items.first;
      return await selected.getDownloadURL();
    } catch (e) {
      debugPrint('Storage fetch error for $path: $e');
      return null;
    }
  }

  Future<String?> _fetchFirst3DModelInFolder(String path) async {
    try {
      debugPrint('🔍 Fetching 3D model from: $path');
      final ref = FirebaseStorage.instance.ref(path);
      final result = await ref.listAll();
      if (result.items.isEmpty) {
        debugPrint('❌ No 3D models found in storage path: $path');
        return null;
      }
      debugPrint('📁 Found ${result.items.length} items in $path');
      Reference? selected;
      // Look for .glb or .gltf files (preferred formats for model_viewer_plus)
      for (final item in result.items) {
        final name = item.name.toLowerCase();
        debugPrint('   - File: ${item.name}');
        if (name.endsWith('.glb') || name.endsWith('.gltf')) {
          selected = item;
          break;
        }
      }
      if (selected == null) {
        debugPrint('❌ No .glb or .gltf files found in $path');
        return null;
      }
      final url = await selected.getDownloadURL();
      debugPrint('✅ 3D Model URL: $url');
      return url;
    } catch (e) {
      debugPrint('❌ 3D model fetch error for $path: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final petImageUrl = _categoryImageUrls[_selectedCategory];
    final petModelUrl = _categoryModelUrls[_selectedCategory];
    final petName = widget.pet['name'] ?? l10n.pets;
    
    // Debug log for 3D mode
    if (_use3DMode) {
      debugPrint('🎨 Rendering in 3D mode');
      debugPrint('   Category: $_selectedCategory');
      debugPrint('   Model URL: ${petModelUrl ?? "NULL"}');
      debugPrint('   Offset: $_stickerOffset');
      debugPrint('   Scale: $_stickerScale');
      debugPrint('   Rotation: $_stickerRotation');
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.petTryOn(petName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l10n.captureAndSave,
            onPressed: _captureScreenshot,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible controls
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _controlsExpanded ? null : 0,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildModeSwitcher(l10n),
                  _build2D3DToggle(l10n),
                  _buildCategorySelector(l10n),
                  _buildWeightSlider(l10n),
                  _buildFlipControls(l10n),
                ],
              ),
            ),
          ),
          // Collapse/Expand button
          _buildCollapseButton(l10n),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return RepaintBoundary(
                  key: _captureKey,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildBackground(l10n)),
                      // Both 2D and 3D use GestureDetector for widget position/scale
                      // 3D: ModelViewer handles internal rotation/zoom via cameraControls
                      // 2D: GestureDetector handles everything (position, scale, rotate)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onScaleStart: (d) => _onScaleStart(d, size),
                          onScaleUpdate: (d) => _onScaleUpdate(d, size),
                          child: _use3DMode && petModelUrl != null
                              ? IgnorePointer(
                                  ignoring: _isCapturing3D,
                                  child: Model3DOverlay(
                                    modelUrl: petModelUrl,
                                    offset: _stickerOffset,
                                    scale: _stickerScale,
                                    rotationY: _stickerRotation * 57.2958,
                                    flipHorizontal: _flipHorizontal,
                                    flipVertical: _flipVertical,
                                  ),
                                )
                              : _StickerOverlay(
                                  imageUrl: petImageUrl ?? '',
                                  offset: _stickerOffset,
                                  scale: _stickerScale,
                                  rotation: _stickerRotation,
                                  flipHorizontal: _flipHorizontal,
                                  flipVertical: _flipVertical,
                                ),
                        ),
                      ),
                      if (_hintVisible)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _buildHintBar(l10n),
                        ),
                      // Reset button for 3D mode (bottom-right corner)
                      if (_use3DMode && !_hintVisible)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            onPressed: () {
                              setState(() {
                                _stickerOffset = const Offset(0, 0);
                                _stickerScale = 0.3;
                                _stickerRotation = 0.0;
                              });
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.54),
                            tooltip: 'Reset vị trí',
                            child: Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                      if (_error != null)
                        Positioned.fill(
                          child: Container(
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.54),
                            alignment: Alignment.center,
                            child: Text(
                              _error!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapseButton(AppLocalizations l10n) {
    return InkWell(
      onTap: () => setState(() => _controlsExpanded = !_controlsExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _controlsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              _controlsExpanded ? l10n.collapseControls : l10n.expandControls,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2D3DToggle(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.view_in_ar, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(
            l10n.renderMode,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.mode2D, style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.image, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.mode3D, style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.threed_rotation, size: 16),
              ),
            ],
            selected: {_use3DMode},
            onSelectionChanged: (Set<bool> newSelection) async {
              final switching = newSelection.first;
              if (switching && !_use3DMode) {
                // Show loading when switching to 3D
                DialogHelper.showLoadingDialog(context, message: 'Đang tải 3D model...');
                await Future.delayed(const Duration(milliseconds: 500));
                await DialogHelper.safeHideLoadingDialog();
              }
              setState(() {
                _use3DMode = switching;
              });
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed:
                  _useLiveCamera ? () => _switchMode(false) : _pickRoomPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _useLiveCamera ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8) : Colors.green[700],
              ),
              child: Text(_roomPhoto == null ? l10n.capturePhoto : l10n.retakePhoto),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: !_useLiveCamera ? () => _switchMode(true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _useLiveCamera ? Colors.green[700] : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
              child: Text(l10n.liveCamera),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.petCategory,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _categories.map((category) {
              final isSelected = category == _selectedCategory;
              final categoryName = category == 'Dog' ? l10n.dog :
                                    category == 'Cat' ? l10n.cat :
                                    category == 'Fish' ? l10n.fish : l10n.bird;
              final loading = _categoryLoading.contains(category);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => _changePetCategory(category),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                _categoryIcons[category],
                                size: 24,
                                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              if (loading)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color:
                                  isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSlider(AppLocalizations l10n) {
    final range = _categoryWeightRanges[_selectedCategory]!;
    final min = range['min']!;
    final max = range['max']!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.petSize,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              Text(
                l10n.weightKg(_petWeightKg.toStringAsFixed(_petWeightKg < 1 ? 2 : 1)),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveTrackColor: Theme.of(context).dividerColor,
              thumbColor: Theme.of(context).primaryColor,
              overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _petWeightKg,
              min: min,
              max: max,
              divisions: ((max - min) * 10).toInt(),
              onChanged: _onWeightChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.weightKg(min.toStringAsFixed(min < 1 ? 2 : 0)),
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              Text(
                l10n.weightKg(max.toStringAsFixed(0)),
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(AppLocalizations l10n) {
    if (!_useLiveCamera) {
      if (_roomPhoto != null) {
        return Image.file(File(_roomPhoto!.path), fit: BoxFit.cover);
      }
      return Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: Text(
          l10n.noRoomPhoto,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_cameraInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    // Safe camera preview with null checks
    if (_cameraController != null && 
        _cameraController!.value.isInitialized &&
        mounted) {
      try {
        return CameraPreview(_cameraController!);
      } catch (e) {
        debugPrint('CameraPreview error: $e');
        return Center(
          child: Text(
            l10n.cameraInitError(e.toString()),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        );
      }
    }
    return Center(
      child: Text(
        l10n.initializingCamera,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      ),
    );
  }

  Widget _buildFlipControls(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flip, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.flip,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _flipHorizontal = !_flipHorizontal),
                  icon: Icon(
                    Icons.flip,
                    size: 20,
                    color: _flipHorizontal ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  label: Text(
                    l10n.flipHorizontal,
                    style: TextStyle(
                      fontSize: 12,
                      color: _flipHorizontal ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _flipHorizontal
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                    elevation: _flipHorizontal ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _flipVertical = !_flipVertical),
                  icon: Transform.rotate(
                    angle: 1.5708, // 90 degrees in radians
                    child: Icon(
                      Icons.flip,
                      size: 20,
                      color: _flipVertical ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  label: Text(
                    l10n.flipVertical,
                    style: TextStyle(
                      fontSize: 12,
                      color: _flipVertical ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _flipVertical
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                    elevation: _flipVertical ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintBar(AppLocalizations l10n) {
    final hintText = _use3DMode 
        ? '👆 1 ngón: Di chuyển widget • 👌 2 ngón: Phóng to widget + Xoay model 3D'
        : l10n.gestureHint;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.54),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_use3DMode)
            Icon(Icons.threed_rotation, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
          if (_use3DMode)
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _hintVisible = false),
            child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 18),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.petTryOnGuideTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.guideStep1),
            const SizedBox(height: 8),
            Text(l10n.guideStep2),
            const SizedBox(height: 8),
            Text(l10n.guideStep3),
            const SizedBox(height: 8),
            Text(l10n.guideStep4),
            const SizedBox(height: 8),
            Text(l10n.guideStep5),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.understood)),
        ],
      ),
    );
  }
}

// Sticker overlay widget (unchanged)
class _StickerOverlay extends StatefulWidget {
  final String imageUrl;
  final Offset offset;
  final double scale;
  final double rotation;
  final bool flipHorizontal;
  final bool flipVertical;

  const _StickerOverlay({
    required this.imageUrl,
    required this.offset,
    required this.scale,
    required this.rotation,
    required this.flipHorizontal,
    required this.flipVertical,
  });

  @override
  State<_StickerOverlay> createState() => _StickerOverlayState();
}

class _StickerOverlayState extends State<_StickerOverlay> {
  ui.Image? _cachedImage;
  bool _loading = false;
  String? _lastUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImageIfNeeded();
  }

  @override
  void didUpdateWidget(_StickerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImageIfNeeded();
    }
  }

  void _loadImageIfNeeded() {
    if (_lastUrl == widget.imageUrl && _cachedImage != null) return;
    if (_loading) return;
    _lastUrl = widget.imageUrl;
    _loading = true;
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final uri = Uri.tryParse(widget.imageUrl);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final response = await http.get(uri);
        final bytes = response.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _cachedImage = frame.image;
            _loading = false;
          });
        }
      } else {
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder);
        c.drawRect(const Rect.fromLTWH(0, 0, 200, 200),
            Paint()..color = Colors.orangeAccent);
        final picture = recorder.endRecording();
        final placeholderImage = await picture.toImage(200, 200);
        if (mounted) {
          setState(() {
            _cachedImage = placeholderImage;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StickerPainter(
        image: _cachedImage,
        offset: widget.offset,
        scale: widget.scale,
        rotation: widget.rotation,
        flipHorizontal: widget.flipHorizontal,
        flipVertical: widget.flipVertical,
      ),
    );
  }
}

class _StickerPainter extends CustomPainter {
  final ui.Image? image;
  final Offset offset;
  final double scale;
  final double rotation;
  final bool flipHorizontal;
  final bool flipVertical;

  _StickerPainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.rotation,
    required this.flipHorizontal,
    required this.flipVertical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      final paint = Paint()..color = const Color(0x3DFFFFFF);
      canvas.drawCircle(size.center(Offset.zero) + offset, 40, paint);
      return;
    }
    final img = image!;
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();

    canvas.save();
    final center = size.center(Offset.zero) + offset;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    // Apply flip transformations
    final scaleX = flipHorizontal ? -scale : scale;
    final scaleY = flipVertical ? -scale : scale;
    canvas.scale(scaleX, scaleY);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: imgW, height: imgH);
    paintImage(canvas: canvas, rect: rect, image: img, fit: BoxFit.contain);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StickerPainter oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.scale != scale ||
        oldDelegate.rotation != rotation ||
        oldDelegate.flipHorizontal != flipHorizontal ||
        oldDelegate.flipVertical != flipVertical ||
        oldDelegate.image != image;
  }
}
