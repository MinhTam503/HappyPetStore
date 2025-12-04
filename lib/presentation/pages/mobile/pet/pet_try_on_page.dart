import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:pet_shop/presentation/widgets/model_3d_overlay.dart';

/// Pet Try-On MVP with collapsible controls and weight-based sizing
/// Fixed camera disposal crash on Android/iOS
class PetTryOnPage extends StatefulWidget {
  final Map<String, dynamic> pet;
  const PetTryOnPage({super.key, required this.pet});

  @override
  State<PetTryOnPage> createState() => _PetTryOnPageState();
}

class _PetTryOnPageState extends State<PetTryOnPage>
    with WidgetsBindingObserver {
  final GlobalKey _captureKey = GlobalKey();
  CameraController? _cameraController;
  bool _cameraInitializing = false;
  String? _error;
  bool _hintVisible = true;

  // Collapsible controls
  bool _controlsExpanded = true;

  // Sticker transform
  Offset _stickerOffset = const Offset(0, 0);
  double _stickerScale = 1.113; // Calculated scale for 10kg dog default
  double _stickerRotation = 0.0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Gesture base values
  Offset _baseOffset = const Offset(0, 0);
  double _baseScale = 1.113; // Match default scale for 10kg
  double _baseRotation = 0.0;

  // Weight-based sizing
  double _petWeightKg = 10.0;
  bool _controlsVisible = false; // show/hide movement pad

  // 3D capture flag
  bool _isCapturing3D = false;
  bool _isLoadingInitialModel = true;

  final Map<String, Map<String, double>> _categoryWeightRanges = {
    'Dog': {'min': 1.0, 'max': 50.0, 'default': 10.0},
    'Cat': {'min': 1.0, 'max': 10.0, 'default': 4.0},
    'Fish': {'min': 0.1, 'max': 5.0, 'default': 0.5},
    'Bird': {'min': 0.05, 'max': 2.0, 'default': 0.3},
  };

  // Category selection + dynamic 3D model handling
  String _selectedCategory = 'Dog';
  final List<String> _categories = ['Dog', 'Cat', 'Fish', 'Bird'];
  final Map<String, String> _categoryModelUrls =
      {}; // Fetched download URLs (3D)
  final Set<String> _categoryLoading = {}; // Loading state per category
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

  Future<void> _initializePetCategory() async {
    final petType = (widget.pet['type'] ?? widget.pet['category'] ?? 'Dog')
        .toString()
        .toLowerCase();
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
    // Load model BEFORE showing UI to prevent NULL url
    await _ensureCategoryImageLoadedAsync(_selectedCategory);
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
      if (mounted) {
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

  void _onScaleStart(ScaleStartDetails details, Size canvasSize) {
    _baseOffset = _stickerOffset;
    _baseScale = _stickerScale;
    _baseRotation = _stickerRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size canvasSize) {
    try {
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

        // Rotation not used for 3D mode
        newRotation = _baseRotation + details.rotation;

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

        // Update weight slider ONLY when actually scaling (2+ fingers)
        if (!isSingleFinger && (newScale - _baseScale).abs() > 0.01) {
          _updateWeightFromScale(newScale);
        }
      });
    } catch (e) {
      debugPrint('❌ Scale update error: $e');
    }
  }

  void _updateWeightFromScale(double scale) {
    final range = _categoryWeightRanges[_selectedCategory]!;
    // Reverse of: scale = 0.8 + (normalized * 1.7)
    final normalized = (scale - 0.8) / 1.7;
    final weight =
        range['min']! + (normalized * (range['max']! - range['min']!));
    _petWeightKg = weight.clamp(range['min']!, range['max']!);
    _baseScale = scale; // Update base for next gesture
  }

  void _updateScaleFromWeight() {
    final range = _categoryWeightRanges[_selectedCategory]!;
    final normalized =
        (_petWeightKg - range['min']!) / (range['max']! - range['min']!);
    // Scale range 0.8 to 2.5 for realistic pet sizes
    // 1kg dog = 0.8 scale (~200px), 50kg dog = 2.5 scale (~625px)
    final newScale = 0.8 + (normalized * 1.7);
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

  Future<void> _ensureCategoryImageLoadedAsync(String category) async {
    if (_categoryModelUrls.containsKey(category)) {
      if (mounted) {
        setState(() {
          _isLoadingInitialModel = false;
        });
      }
      return;
    }
    if (_categoryLoading.contains(category)) return;

    _categoryLoading.add(category);
    final folder3D = _category3DFolderNames[category] ?? '${category}_3D';

    // Show loading only when fetching current category for first time
    final shouldShowOverlay = category == _selectedCategory;
    if (shouldShowOverlay && mounted) {
      // Use addPostFrameCallback to avoid "called during build" error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryLoading.contains(category)) {
          DialogHelper.showLoadingDialog(context);
        }
      });
    }

    // Load 3D model and WAIT for it
    final url = await _fetchFirst3DModelInFolder('3d_model/$folder3D');

    if (!mounted) return;
    setState(() {
      if (url != null) {
        _categoryModelUrls[category] = url;
      }
      _categoryLoading.remove(category);
      _isLoadingInitialModel = false;
    });

    if (shouldShowOverlay) {
      DialogHelper.safeHideLoadingDialog();
    }
  }

  void _ensureCategoryImageLoaded(String category) {
    // Non-blocking version for category switching
    _ensureCategoryImageLoadedAsync(category);
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
    final petModelUrl = _categoryModelUrls[_selectedCategory];
    final petName = widget.pet['name'] ?? l10n.pets;

    // Debug log for 3D mode
    debugPrint('🎨 Rendering 3D Pet Try-On');
    debugPrint('   Category: $_selectedCategory');
    debugPrint('   Model URL: ${petModelUrl ?? "NULL"}');
    debugPrint('   Offset: $_stickerOffset');
    debugPrint('   Scale: $_stickerScale');
    debugPrint('   Rotation: $_stickerRotation');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.petTryOn(petName)),
        actions: [
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
                      // Show loading while fetching model
                      if (_isLoadingInitialModel)
                        Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      // 3D Model with gesture controls - only show when URL is ready
                      if (!_isLoadingInitialModel && petModelUrl != null)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () {
                            setState(() {
                              _stickerOffset = const Offset(0, 0);
                            });
                          },
                          onScaleStart: (d) => _onScaleStart(d, size),
                          onScaleUpdate: (d) => _onScaleUpdate(d, size),
                          child: IgnorePointer(
                            ignoring: _isCapturing3D,
                            child: Model3DOverlay(
                              modelUrl: petModelUrl,
                              offset: _stickerOffset,
                              scale: _stickerScale.clamp(0.1, 5.0),
                              rotationY: _stickerRotation * 57.2958,
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
                      // Bottom-right controls: toggle + optional movement pad
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Visibility toggle button
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'Ẩn/Hiện điều khiển',
                                icon: Icon(_controlsVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _controlsVisible = !_controlsVisible),
                              ),
                            ),
                            // const SizedBox(height: 8),
                            if (_controlsVisible)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MovementButton(
                                            icon: Icons.keyboard_arrow_up,
                                            onPressed: () {
                                              setState(() {
                                                _stickerOffset = Offset(
                                                    _stickerOffset.dx,
                                                    _stickerOffset.dy - 20);
                                              });
                                            }),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MovementButton(
                                            icon: Icons.keyboard_arrow_left,
                                            onPressed: () {
                                              setState(() {
                                                _stickerOffset = Offset(
                                                    _stickerOffset.dx - 20,
                                                    _stickerOffset.dy);
                                              });
                                            }),
                                        const SizedBox(width: 6),
                                        _MovementButton(
                                            icon: Icons.my_location,
                                            onPressed: () {
                                              setState(() {
                                                // Only reset position, keep current weight/size
                                                _stickerOffset =
                                                    const Offset(0, 0);
                                                // Ensure scale stays at current weight
                                                // (no reset to default)
                                              });
                                            }),
                                        const SizedBox(width: 6),
                                        _MovementButton(
                                            icon: Icons.keyboard_arrow_right,
                                            onPressed: () {
                                              setState(() {
                                                _stickerOffset = Offset(
                                                    _stickerOffset.dx + 20,
                                                    _stickerOffset.dy);
                                              });
                                            }),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MovementButton(
                                            icon: Icons.keyboard_arrow_down,
                                            onPressed: () {
                                              setState(() {
                                                _stickerOffset = Offset(
                                                    _stickerOffset.dx,
                                                    _stickerOffset.dy + 20);
                                              });
                                            }),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 80),
                            // Reset all button
                            // FloatingActionButton.small(
                            //   onPressed: () {
                            //     setState(() {
                            //       _stickerOffset = const Offset(0, 0);
                            //       _stickerScale = 0.3;
                            //       _stickerRotation = 0.0;
                            //     });
                            //   },
                            //   backgroundColor: Theme.of(context)
                            //       .colorScheme
                            //       .surface
                            //       .withOpacity(0.0),
                            //   tooltip: 'Reset vị trí',
                            //   child: Icon(Icons.restart_alt,
                            //       color:
                            //           Theme.of(context).colorScheme.onSurface),
                            // ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Positioned.fill(
                          child: Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.54),
                            alignment: Alignment.center,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
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
              _controlsExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
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
              Icon(Icons.category,
                  size: 18,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.petCategory,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _categories.map((category) {
              final isSelected = category == _selectedCategory;
              final categoryName = category == 'Dog'
                  ? l10n.dog
                  : category == 'Cat'
                      ? l10n.cat
                      : category == 'Fish'
                          ? l10n.fish
                          : l10n.bird;
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
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                              ),
                              if (loading)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : Theme.of(context).primaryColor,
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
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
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
              Icon(Icons.straighten,
                  size: 18,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.petSize,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              Text(
                l10n.weightKg(
                    _petWeightKg.toStringAsFixed(_petWeightKg < 1 ? 2 : 1)),
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
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
              ),
              Text(
                l10n.weightKg(max.toStringAsFixed(0)),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(AppLocalizations l10n) {
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
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        );
      }
    }
    return Center(
      child: Text(
        l10n.initializingCamera,
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
              Icon(Icons.flip,
                  size: 18,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                l10n.flip,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _flipHorizontal = !_flipHorizontal),
                  icon: Icon(
                    Icons.flip,
                    size: 20,
                    color: _flipHorizontal
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                  ),
                  label: Text(
                    l10n.flipHorizontal,
                    style: TextStyle(
                      fontSize: 12,
                      color: _flipHorizontal
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
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
                  onPressed: () =>
                      setState(() => _flipVertical = !_flipVertical),
                  icon: Transform.rotate(
                    angle: 1.5708, // 90 degrees in radians
                    child: Icon(
                      Icons.flip,
                      size: 20,
                      color: _flipVertical
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                    ),
                  ),
                  label: Text(
                    l10n.flipVertical,
                    style: TextStyle(
                      fontSize: 12,
                      color: _flipVertical
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
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
    const hintText =
        '1 ngón: Di chuyển • 2 ngón: Phóng to/thu nhỏ • Xoay dùng điều khiển';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.54),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _hintVisible = false),
            child: Icon(Icons.close,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 18),
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

class _MovementButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MovementButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.6)),
        ),
        child: Icon(icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
      ),
    );
  }
}
