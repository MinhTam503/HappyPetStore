import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/core/constants/pet_colors.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/empty_state.dart';
import '../../model/pet_model.dart';

import 'components/pet_card.dart';
import 'components/pet_details_dialog.dart';
import 'components/bulk_print_qr_dialog.dart';
import 'bloc/bloc.dart';

class PetsAdmin extends StatefulWidget {
  const PetsAdmin({super.key});

  @override
  State<PetsAdmin> createState() => _PetsState();
}

class _PetsState extends State<PetsAdmin> {
  Uint8List? _imageBytes;
  bool _imageError = false;

  final CollectionReference petsCollection =
      FirebaseFirestore.instance.collection('Pets');

  List<String> categories = ['All']; // Will be loaded dynamically
  final TextEditingController _searchController = TextEditingController();
  bool _categoriesLoaded = false;

  List<String> breedsList = [];
  String? selectedBreed;

  final List<String> genderOptions = const ['Male', 'Female'];

  String? selectedColor;
  
  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 12;

  // ===== Load Categories from Firestore =====
  Future<void> _loadCategories() async {
    if (_categoriesLoaded) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Category')
          .get();
      
      if (mounted) {
        setState(() {
          categories = ['All'];
          categories.addAll(
            snapshot.docs.map((doc) => doc.data()['name'] as String? ?? '').where((name) => name.isNotEmpty)
          );
          _categoriesLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      // Keep default categories if load fails
      if (mounted) {
        setState(() {
          categories = ['All', 'Dogs', 'Cats', 'Fish', 'Birds'];
          _categoriesLoaded = true;
        });
      }
    }
  }

  // ===== Storage =====
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
      });
    }
  }

  // ===== UI =====
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _input(String label, {Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Load categories dynamically on first build
    if (!_categoriesLoaded) {
      _loadCategories();
    }
    
    return BlocProvider(
      create: (context) => PetBloc()..add(LoadPetsEvent()),
      child: Builder(
        builder: (context) {
          return BlocListener<PetBloc, PetState>(
            listener: (context, state) {
              // Hide loading dialog on success or error
              if (state is PetActionSuccess || state is PetError) {
                DialogHelper.safeHideLoadingDialog();
              }
              
              // Handle success messages
              if (state is PetActionSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
              // Handle error messages
              if (state is PetError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              // Handle breeds loaded
              if (state is BreedsLoaded) {
                setState(() {
                  breedsList = state.breeds;
                  selectedBreed = breedsList.isNotEmpty ? breedsList.first : null;
                });
              }
            },
            child: _buildScaffold(context, l10n),
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<PetBloc, PetState>(
          builder: (context, state) {
            final selectedCategory = state is PetLoaded ? state.selectedCategory : 'All';
            
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                title: Row(
                  children: [
                    Text(l10n.managePets,
                        style: TextStyle(
                            color: Theme.of(context).appBarTheme.foregroundColor)),
                    const SizedBox(width: 12),
                    Card(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => _showPetDialog(context),
                        icon: Icon(Icons.add,
                            color: Theme.of(context).colorScheme.primary),
                        label: Text(l10n.addPet,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary)),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Print QR Codes button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      onPressed: () => _showBulkPrintDialog(),
                      icon: const Icon(Icons.print),
                      tooltip: l10n.printQRCodes,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      height: 40,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in categories)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: selectedCategory == c,
                                  selectedColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(.15),
                                  backgroundColor:
                                      Theme.of(context).chipTheme.backgroundColor,
                                  labelStyle: TextStyle(
                                    color: selectedCategory == c
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  onSelected: (_) {
                                    setState(() => _currentPage = 0);
                                    context.read<PetBloc>().add(FilterPetsByCategoryEvent(c));
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() => _currentPage = 0);
                          context.read<PetBloc>().add(SearchPetsEvent(v.trim()));
                        },
                        decoration: InputDecoration(
                          hintText: l10n.searchPetsByName,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: Builder(
                builder: (context) {
                  // Handle loading state
                  if (state is PetLoading || state is PetActionInProgress) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            state is PetActionInProgress 
                                ? state.message 
                                : l10n.loading,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ],
                      ),
                    );
                  }

                  // Handle error state
                  if (state is PetError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, 
                               size: 48, 
                               color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(state.message),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.read<PetBloc>().add(LoadPetsEvent()),
                            child:  Text(l10n.retry),
                          ),
                        ],
                      ),
                    );
                  }

                  // Handle loaded state
                  if (state is PetLoaded) {
                    if (state.filteredPets.isEmpty) {
                      return EmptyState(
                        label: l10n.noPetsFound,
                        icon: Icons.pets_outlined,
                      );
                    }

                    // Pagination logic
                    final totalPets = state.filteredPets.length;
                    final totalPages = (totalPets / _itemsPerPage).ceil();
                    final startIndex = _currentPage * _itemsPerPage;
                    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalPets);
                    final paginatedPets = state.filteredPets.sublist(startIndex, endIndex);

                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth ~/ 320;
                          return CustomScrollView(
                            slivers: [
                              SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount.clamp(1, 5),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 3 / 2,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => PetCard(
                                    pet: paginatedPets[i],
                                    onEdit: () => _showPetDialog(context, pet: paginatedPets[i]),
                                    onDelete: () => _confirmDelete(context, paginatedPets[i].id),
                                    onTap: () => _showPetDetailsDialog(paginatedPets[i]),
                                  ),
                                  childCount: paginatedPets.length,
                                ),
                              ),
                              // Pagination controls at the end of list
                              if (totalPages > 1)
                                SliverToBoxAdapter(
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Previous button
                                IconButton(
                                  onPressed: _currentPage > 0
                                      ? () => setState(() => _currentPage--)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  tooltip: l10n.previous,
                                  style: IconButton.styleFrom(
                                    backgroundColor: _currentPage > 0
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Page numbers
                                ...List.generate(
                                  totalPages > 7 ? 7 : totalPages,
                                  (index) {
                                    int pageNum;
                                    if (totalPages <= 7) {
                                      pageNum = index;
                                    } else {
                                      // Show current page with 3 pages before and after
                                      if (_currentPage < 3) {
                                        pageNum = index;
                                      } else if (_currentPage > totalPages - 4) {
                                        pageNum = totalPages - 7 + index;
                                      } else {
                                        pageNum = _currentPage - 3 + index;
                                      }
                                    }
                                    
                                    if (pageNum >= totalPages) return const SizedBox.shrink();
                                    
                                    final isSelected = pageNum == _currentPage;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: InkWell(
                                        onTap: () => setState(() => _currentPage = pageNum),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).dividerColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${pageNum + 1}',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Theme.of(context).colorScheme.onPrimary
                                                  : Theme.of(context).colorScheme.onSurface,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                const SizedBox(width: 8),
                                // Next button
                                IconButton(
                                  onPressed: _currentPage < totalPages - 1
                                      ? () => setState(() => _currentPage++)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  tooltip: l10n.next,
                                  style: IconButton.styleFrom(
                                    backgroundColor: _currentPage < totalPages - 1
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                        : null,
                                  ),
                                ),
                                
                                // const SizedBox(width: 16),
                                // // Page info
                                // Text(
                                //   '${startIndex + 1}-$endIndex of $totalPets',
                                //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                //         color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                //       ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                            ],
                          );
                        },
                      ),
                    );
                  }

                  // Default fallback
                  return EmptyState(
                    label: l10n.noPetsFound,
                    icon: Icons.pets_outlined,
                  );
                },
              ),
            );
          },
        );
  }

  Future<void> _confirmDelete(BuildContext blocContext, String id) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Get pet data to extract imageUrl
    final doc = await petsCollection.doc(id).get();
    if (!doc.exists) return;
    
    final imageUrl = doc['imageUrl'] as String? ?? '';
    
    if (!mounted) return;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text(l10n.confirmDeletePet),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (ok == true && mounted) {
      // Show loading dialog
      DialogHelper.showLoadingDialog(context, message: l10n.deletingPet);
      
      // Dispatch delete event
      blocContext.read<PetBloc>().add(DeletePetEvent(petId: id, imageUrl: imageUrl));
    }
  }

  void _showPetDialog(BuildContext blocContext, {Pet? pet}) async {
    // Reset image bytes khi mở dialog để hiển thị đúng hình hiện tại
    setState(() { _imageBytes = null; _imageError = false; });

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: pet?.name);
    final imageController = TextEditingController(text: pet?.imageUrl);
    final ageController = TextEditingController(text: pet?.age);
    final aboutController = TextEditingController(text: pet?.about);
    final genderController = TextEditingController(text: pet?.gender);
    final priceController = TextEditingController(text: pet?.price?.toString() ?? '');
    final weightController = TextEditingController(text: pet?.weight ?? '');

    String pickedCategory = pet?.category ?? 'Dogs';
    bool isAvailable = pet?.isAvailable ?? true;

    // Store the bloc reference before showing dialog
    final petBloc = blocContext.read<PetBloc>();

    if (pet != null) {
      petBloc.add(LoadBreedsEvent(pet.category));
      // Inject pet.breed if not in list and not empty
      if (pet.breed.isNotEmpty && !breedsList.contains(pet.breed)) {
        breedsList = [...breedsList, pet.breed];
      }
      // Deduplicate while preserving order
      final seen = <String>{};
      breedsList = breedsList.where((b) => seen.add(b)).toList();
      selectedBreed = pet.breed.isNotEmpty ? pet.breed : null;
      selectedColor = (pet.color != null && PetColors.colorKeys.contains(pet.color)) ? pet.color : null; // Khởi tạo màu sắc hiện tại (an toàn)
    } else {
      petBloc.add(LoadBreedsEvent(pickedCategory));
      // Deduplicate list just in case
      final seen = <String>{};
      breedsList = breedsList.where((b) => seen.add(b)).toList();
      selectedColor = null; // Reset màu sắc cho pet mới
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
    return StatefulBuilder(
          builder: (context, setStateDialog) {
            final l10n = AppLocalizations.of(context)!;
      // Safe values for dropdowns to avoid assertion: value must be null or exactly one match
      final genderValue = genderController.text.isNotEmpty && ['Male','Female'].contains(genderController.text)
        ? genderController.text
        : null;
      final breedValue = (selectedBreed != null && breedsList.contains(selectedBreed))
        ? selectedBreed
        : null;
      final colorValue = (selectedColor != null && PetColors.colorKeys.contains(selectedColor))
        ? selectedColor
        : null;
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(pet == null ? l10n.addPet : l10n.edit),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: nameController,
                                    decoration: _input(l10n.name,
                                        prefix:
                                            const Icon(Icons.badge_outlined)),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.pleaseEnterName;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: pickedCategory,
                                    decoration: _input(l10n.category,
                                        prefix: const Icon(
                                            Icons.category_outlined)),
                                    onChanged: (v) async {
                                      setStateDialog(() {
                                        pickedCategory = v!;
                                        selectedBreed = null;
                                        breedsList = [];
                                      });
                                      petBloc.add(LoadBreedsEvent(pickedCategory));
                                      setStateDialog(() {});
                                    },
                                    items: categories
                                        .sublist(1)
                                        .map((e) => DropdownMenuItem(
                                            value: e, child: Text(e)))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  if (breedsList.isNotEmpty)
                                    DropdownButtonFormField<String>(
                                      value: breedValue,
                                      decoration: _input(l10n.breed,
                                          prefix:
                                              const Icon(Icons.pets_outlined)),
                                      onChanged: (v) => setStateDialog(
                                          () => selectedBreed = v),
                                      items: breedsList.toSet().toList()
                                          .map((e) => DropdownMenuItem(
                                              value: e, child: Text(e)))
                                          .toList(),
                                    ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: priceController,
                                    decoration: _input(l10n.price,
                                        prefix: const Icon(Icons.attach_money)),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Vui lòng nhập giá';
                                      }
                                      if (double.tryParse(value.trim()) == null) {
                                        return 'Giá phải là số';
                                      }
                                      if (double.parse(value.trim()) <= 0) {
                                        return 'Giá phải lớn hơn 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: weightController,
                                    decoration: _input(l10n.weight,
                                        prefix: const Icon(Icons.monitor_weight)),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Vui lòng nhập cân nặng';
                                      }
                                      if (double.tryParse(value.trim()) == null) {
                                        return 'Cân nặng phải là số';
                                      }
                                      if (double.parse(value.trim()) <= 0) {
                                        return 'Cân nặng phải lớn hơn 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: ageController,
                                    decoration: _input(l10n.age,
                                        prefix:
                                            const Icon(Icons.cake_outlined)),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Vui lòng nhập tuổi';
                                      }
                                      if (int.tryParse(value.trim()) == null) {
                                        return 'Tuổi phải là số nguyên';
                                      }
                                      if (int.parse(value.trim()) <= 0) {
                                        return 'Tuổi phải lớn hơn 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: genderValue,
                                    decoration: _input(l10n.gender,
                                        prefix: const Icon(Icons.wc_outlined)),
                                    onChanged: (v) => setStateDialog(
                                        () => genderController.text = v ?? ''),
                                    items: genderOptions
                                        .map((e) => DropdownMenuItem(
                                            value: e, child: Text(e)))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: colorValue,
                                    decoration: _input(l10n.color,
                                        prefix:
                                            const Icon(Icons.palette_outlined)),
                                    hint: Text(l10n.selectColor),
                                    onChanged: (v) =>
                                        setStateDialog(() => selectedColor = v),
                                    items: PetColors.colorKeys
                                        .map((colorKey) => DropdownMenuItem(
                                            value: colorKey,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: PetColors.getColorFromKey(
                                                        colorKey),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(PetColors.getLocalizedColor(
                                                    l10n, colorKey)),
                                              ],
                                            )))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.store_outlined, 
                                           color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(l10n.availableForSale,
                                          style: const TextStyle(fontSize: 16)),
                                      const Spacer(),
                                      Switch(
                                        value: isAvailable,
                                        onChanged: (value) => setStateDialog(() => isAvailable = value),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: aboutController,
                                    minLines: 4,
                                    maxLines: 10,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.newline,
                                    decoration: _input(l10n.about,
                                        prefix: const Icon(
                                            Icons.description_outlined)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Preview + Pick
                            SizedBox(
                              width: 220,
                              child: Column(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: secondaryColor,
                                          border: Border.all(
                                              color: primaryColor
                                                  .withOpacity(.25)),
                                        ),
                                        child: _imageBytes != null
                                            ? FittedBox(
                                                fit: BoxFit.contain,
                                                // hiển thị nguyên hình
                                                child:
                                                    Image.memory(_imageBytes!),
                                              )
                                            : (pet != null
                                                ? FittedBox(
                                                    fit: BoxFit.contain,
                                                    // hiển thị nguyên hình
                                                    child: Image.network(
                                                        pet.imageUrl),
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                        Icons.image_outlined,
                                                        size: 48))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.photo_library_outlined),
                                          onPressed: () async {
                                            await _pickImage();
                                            setStateDialog(() { _imageError = false; });
                                          },
                                          label: Text(l10n.pickImage),
                                        ),
                                      ),
                                      if (pet != null && _imageBytes != null) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Clear',
                                          onPressed: () {
                                            setStateDialog(() { _imageBytes = null; });
                                          },
                                          icon: const Icon(Icons.clear),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (pet == null && _imageError)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(
                                          l10n.pleaseSelectImage,
                                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _imageBytes = null;
                  },
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () async {
                    debugPrint('=== Form Submit Started ===');
                    
                    // Validate using Form
                    if (!formKey.currentState!.validate()) {
                      debugPrint('Form validation failed');
                      return;
                    }
                    debugPrint('Form validation passed');

                    // Additional validations
                    if (selectedBreed == null || selectedBreed!.isEmpty) {
                      debugPrint('Breed validation failed: $selectedBreed');
                      _snack(l10n.pleaseSelectBreed);
                      return;
                    }
                    debugPrint('Breed validation passed: $selectedBreed');
                    
                    // Image validation (add requires image, update can keep old)
                    debugPrint('Checking image selection. _imageBytes=${_imageBytes != null ? 'YES' : 'NO'} currentUrl=${pet?.imageUrl}');
                    if (pet == null && _imageBytes == null) {
                      debugPrint('Image validation failed (add)');
                      setStateDialog(() { _imageError = true; });
                      return;
                    }
                    debugPrint('Image validation passed');

                    String imageUrl = imageController.text;
                    final petId = pet?.id ?? const Uuid().v4();
                    
                    // Không upload ảnh ở đây nữa để tránh double upload/delete.
                    // Upload sẽ được thực hiện bên trong addPet/updatePet nếu _imageBytes != null.
                    imageUrl = pet == null ? '' : pet.imageUrl;

                    debugPrint('Creating Pet object...');
                    debugPrint('Name: ${nameController.text}');
                    debugPrint('Category: $pickedCategory');
                    debugPrint('Breed: $selectedBreed');
                    debugPrint('Price: ${priceController.text}');
                    debugPrint('Weight: ${weightController.text}');
                    debugPrint('Age: ${ageController.text}');
                    debugPrint('Gender: ${genderController.text}');
                    debugPrint('Color: $selectedColor');
                    debugPrint('IsAvailable: $isAvailable');

                    final newPet = Pet(
                      id: petId,
                      name: nameController.text.trim(),
                      category: pickedCategory,
                      imageUrl: imageUrl,
                      age: ageController.text.trim(),
                      breed: selectedBreed ?? 'Unknown',
                      about: aboutController.text.trim(),
                      gender: genderController.text.trim(),
                      weight: weightController.text.trim(),
                      price: priceController.text.trim(),
                      color: selectedColor,
                      isAvailable: isAvailable,
                    );

                    debugPrint('Pet object created successfully');

                    // Close form dialog first
                    Navigator.pop(context);

                    // Show loading dialog
                    final l10nContext = AppLocalizations.of(context)!;
                    DialogHelper.showLoadingDialog(
                      context,
                      message: pet == null ? l10nContext.addingPet : l10nContext.updatingPet,
                    );

                    if (pet == null) {
                      debugPrint('Adding new pet...');
                      petBloc.add(AddPetEvent(
                        pet: newPet,
                        imageBytes: _imageBytes!,
                      ));
                      // Clear image bytes after dispatching event
                      setState(() => _imageBytes = null);
                    } else {
                      debugPrint('Updating existing pet...');
                      petBloc.add(UpdatePetEvent(
                        pet: newPet,
                        imageBytes: _imageBytes,
                      ));
                      // Clear image bytes after dispatching event
                      setState(() => _imageBytes = null);
                    }
                  },
                  child: Text(pet == null ? l10n.addPet : l10n.save,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPetDetailsDialog(Pet pet) {
    showDialog(
      context: context,
      builder: (context) => PetDetailsDialog(pet: pet),
    );
  }

  // Show dialog to select multiple pets for printing QR codes
  Future<void> _showBulkPrintDialog() async {
    await showDialog(
      context: context,
      builder: (context) => BulkPrintQRDialog(petsCollection: petsCollection),
    );
  }
}
