import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import '../../components/empty_state.dart';
import 'package:pet_shop/core/utils/currency_helper.dart';
import '../../model/pet_model.dart';

import 'components/pet_card.dart';

class PetsAdmin extends StatefulWidget {
  const PetsAdmin({super.key});

  @override
  State<PetsAdmin> createState() => _PetsState();
}

class _PetsState extends State<PetsAdmin> {
  Uint8List? _imageBytes;
  bool _imageError = false; // inline validation state for add dialog image

  final CollectionReference petsCollection =
      FirebaseFirestore.instance.collection('Pets');

  // Filters
  String selectedCategory = 'All';
  final List<String> categories = const [
    'All',
    'Dogs',
    'Cats',
    'Fish',
    'Birds'
  ];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool isLoading = false;

  List<String> breedsList = [];
  String? selectedBreed;

  final List<String> genderOptions = const ['Male', 'Female'];

  // Danh sách màu sắc thú cưng
  final List<String> colorKeys = const [
    'colorBrown',
    'colorBlack',
    'colorWhite',
    'colorGray',
    'colorGolden',
    'colorCream',
    'colorOrange',
    'colorBlue',
    'colorGreen',
    'colorRed',
    'colorMixed'
  ];

  String? selectedColor;

  // ===== Storage =====
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      debugPrint('[uploadImage] Start upload. Raw bytes length=${imageBytes.length}, input fileName=$fileName');
      // Detect image format from bytes (robust length checks)
      String ext = 'jpg'; // default
      String contentType = 'image/jpeg'; // default

      bool matches(List<int> sig) {
        if (imageBytes.length < sig.length) return false;
        for (int i = 0; i < sig.length; i++) {
          if (imageBytes[i] != sig[i]) return false;
        }
        return true;
      }

      if (matches([0x89, 0x50, 0x4E, 0x47])) { // PNG
        ext = 'png'; contentType = 'image/png';
      } else if (imageBytes.length >= 2 && imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) { // JPG
        ext = 'jpg'; contentType = 'image/jpeg';
      } else if (matches([0x47, 0x49, 0x46, 0x38])) { // GIF87/89a
        ext = 'gif'; contentType = 'image/gif';
      } else if (imageBytes.length >= 12 &&
          imageBytes[0] == 0x52 && imageBytes[1] == 0x49 && imageBytes[2] == 0x46 && imageBytes[3] == 0x46 &&
          imageBytes[8] == 0x57 && imageBytes[9] == 0x45 && imageBytes[10] == 0x42 && imageBytes[11] == 0x50) { // WEBP
        ext = 'webp'; contentType = 'image/webp';
      }

      // Normalize base name (strip extension if provided)
      final baseFileName = fileName.contains('.') ? fileName.split('.').first : fileName;
      final finalFileName = '$baseFileName.$ext';
      debugPrint('[uploadImage] Detected ext=$ext contentType=$contentType final=$finalFileName');

      final metadata = SettableMetadata(contentType: contentType);
      // Don't save pets in any child folder - directly in root as specified
      final storageRef = FirebaseStorage.instance.ref().child(finalFileName);
      final uploadTask = storageRef.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading pet image: $e');
      return "";
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        // filename not used; only upload image bytes
      });
    }
  }

  // ===== CRUD =====
  Future<void> addPet(Pet pet) async {
    setState(() => isLoading = true);
    
    try {
      debugPrint('=== Adding new pet ===');
      final newId = pet.id.isNotEmpty ? pet.id : const Uuid().v4();
      final existing = await petsCollection.doc(newId).get();
      if (existing.exists) {
        _snack('ID đã tồn tại, vui lòng thử lại!');
        setState(() => isLoading = false);
        return;
      }
      
      // Handle price same as update method
      dynamic priceValue;
      if (pet.price != null) {
        if (pet.price is String) {
          priceValue = double.tryParse(pet.price as String) ?? 0.0;
        } else if (pet.price is num) {
          priceValue = pet.price;
        } else {
          priceValue = 0.0;
        }
      } else {
        priceValue = 0.0;
      }

      if (_imageBytes == null) {
        debugPrint('[addPet] No image bytes present -> abort');
        setState(() { isLoading = false; });
        return; // (UI now blocks earlier; this is safety net)
      }

      debugPrint('[addPet] Uploading image for new pet...');
      final uploadedUrl = await uploadImage(_imageBytes!, newId);
      if (uploadedUrl.isEmpty) {
        debugPrint('[addPet] Upload failed, abort');
        setState(() { isLoading = false; });
        return;
      }
      debugPrint('[addPet] Image uploaded: $uploadedUrl');

      await petsCollection.doc(newId).set({
        'id': newId,
        'name': pet.name.isNotEmpty ? pet.name : 'Unknown',
        'category': pet.category.isNotEmpty ? pet.category : 'Dogs',
        'imageUrl': uploadedUrl,
        'age': pet.age.isNotEmpty ? pet.age : '1',
        'breed': pet.breed.isNotEmpty ? pet.breed : 'Unknown',
        'about': pet.about.isNotEmpty ? pet.about : 'No description',
        'sex': pet.gender.isNotEmpty ? pet.gender : 'Unknown',
        'price': priceValue,
        'weight': pet.weight.isNotEmpty ? pet.weight : '0',
        'color': pet.color ?? '',
        'isAvailable': pet.isAvailable,
      });
      
      callTrainAPI();

      _snack('Thêm thú cưng thành công!');
    } catch (e, stackTrace) {
      debugPrint('Error adding pet: $e');
      debugPrint('Stack trace: $stackTrace');
      _snack('Lỗi thêm thú cưng: $e');
    } finally {
      setState(() {
        _imageBytes = null;
        isLoading = false;
      });
    }
  }

  Future<void> callTrainAPI() async {
    try {
      // final uri = Uri.parse('http://localhost:5000/train');
      final uri = Uri.parse('https://train-pet-image.onrender.com/train');
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        debugPrint('Train thành công!');
      } else {
        debugPrint('Train thất bại: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Lỗi train: $e');
    }
  }

  Future<void> updatePet(Pet pet) async {
    setState(() => isLoading = true);

    try {
      debugPrint('=== Starting updatePet ===');
      debugPrint('Pet ID: ${pet.id}');
      debugPrint('Pet name: ${pet.name}');
      debugPrint('Pet breed: ${pet.breed}');
      debugPrint('Pet price: ${pet.price} (type: ${pet.price.runtimeType})');
      debugPrint('Pet weight: ${pet.weight}');
      debugPrint('Pet isAvailable: ${pet.isAvailable}');
      debugPrint('Pet color: ${pet.color}');
      debugPrint('Pet gender: ${pet.gender}');
      debugPrint('Pet about length: ${pet.about.length}');
      
  // finalImageUrl starts with current image (original from Firestore if editing)
  // We intentionally do NOT upload before calling updatePet to avoid double upload/delete
  String finalImageUrl = pet.imageUrl;
      debugPrint('Initial finalImageUrl: $finalImageUrl');

      if (_imageBytes != null) {
        debugPrint('[updatePet] New image picked. Overwriting existing with same pet.id');
        // Overwrite directly (Firebase Storage replace) – safer than delete then upload
        finalImageUrl = await uploadImage(_imageBytes!, pet.id);
        if (finalImageUrl.isEmpty) {
          _snack('Upload hình mới thất bại!');
          return;
        }
        debugPrint('[updatePet] New image uploaded (overwrite): $finalImageUrl');
      }

      // Đảm bảo tất cả field đều có giá trị hợp lệ và không null - giống như addPet
      debugPrint('Creating updateData map...');
      debugPrint('pet.name: ${pet.name} (${pet.name.runtimeType})');
      debugPrint('pet.category: ${pet.category} (${pet.category.runtimeType})');
      debugPrint('finalImageUrl: $finalImageUrl (${finalImageUrl.runtimeType})');
      debugPrint('pet.age: ${pet.age} (${pet.age.runtimeType})');
      debugPrint('pet.breed: ${pet.breed} (${pet.breed.runtimeType})');
      debugPrint('pet.about: ${pet.about} (${pet.about.runtimeType})');
      debugPrint('pet.gender: ${pet.gender} (${pet.gender.runtimeType})');
      debugPrint('pet.weight: ${pet.weight} (${pet.weight.runtimeType})');
      debugPrint('pet.color: ${pet.color} (${pet.color.runtimeType})');
      debugPrint('pet.isAvailable: ${pet.isAvailable} (${pet.isAvailable.runtimeType})');
      
      Map<String, dynamic> updateData;
      try {
        updateData = <String, dynamic>{
          'name': pet.name.isNotEmpty ? pet.name : 'Unknown',
          'category': pet.category.isNotEmpty ? pet.category : 'Dogs',
          'imageUrl': finalImageUrl.isNotEmpty ? finalImageUrl : pet.imageUrl,
          'age': pet.age.isNotEmpty ? pet.age : '1',
          'breed': pet.breed.isNotEmpty ? pet.breed : 'Unknown',
          'about': pet.about.isNotEmpty ? pet.about : 'No description',
          'sex': pet.gender.isNotEmpty ? pet.gender : 'Unknown',
          'weight': pet.weight.isNotEmpty ? pet.weight : '0',
          'color': pet.color ?? '',
          'isAvailable': pet.isAvailable,
        };
        debugPrint('updateData map created successfully');
      } catch (e) {
        debugPrint('Error creating updateData map: $e');
        throw Exception('Failed to create update data: $e');
      }
      
      // Handle price carefully - same logic as addPet
      if (pet.price != null) {
        if (pet.price is String) {
          final priceValue = double.tryParse(pet.price as String);
          updateData['price'] = priceValue ?? 0.0;
        } else if (pet.price is num) {
          updateData['price'] = pet.price;
        } else {
          updateData['price'] = 0.0;
        }
      } else {
        updateData['price'] = 0.0;
      }
      
      debugPrint('Final update data: $updateData');
      
      // Validate that pet.id exists and is not null/empty
      if (pet.id.isEmpty) {
        throw Exception('Pet ID is empty');
      }
      
      // Check if document exists
      final docExists = await petsCollection.doc(pet.id).get();
      if (!docExists.exists) {
        throw Exception('Pet document does not exist: ${pet.id}');
      }
      
      // Validate all required fields are not null
      for (final entry in updateData.entries) {
        if (entry.value == null) {
          throw Exception('Field ${entry.key} is null');
        }
      }
      
      debugPrint('About to update document: ${pet.id}');
      await petsCollection.doc(pet.id).update(updateData);
      debugPrint('Update completed successfully');

      _snack('Cập nhật thú cưng thành công!');
    } catch (e, stackTrace) {
      debugPrint('Error updating pet: $e');
      debugPrint('Stack trace: $stackTrace');
      _snack('Lỗi cập nhật thú cưng: $e');
    } finally {
      setState(() {
        _imageBytes = null;
        isLoading = false;
      });
    }
  }

  void deletePet(String id) async {
    setState(() => isLoading = true);

    try {
      final doc = await petsCollection.doc(id).get();
      if (doc.exists) {
        final imageUrl = doc['imageUrl'];
        final imageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await imageRef.delete();
      }
      await petsCollection.doc(id).delete();
    } catch (e) {
      _snack('Xóa thú cưng hoặc hình $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> addBreed(String category, String newBreed) async {
    final docRef = FirebaseFirestore.instance.collection('Breed').doc(category);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'breeds': FieldValue.arrayUnion([newBreed])
      });
    } else {
      await docRef.set({
        'breeds': [newBreed]
      });
    }
  }

  Future<void> loadBreeds(String category) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('Category')
        .where('name', isEqualTo: category)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      setState(() {
        breedsList = List<String>.from(doc['breeds']);
        selectedBreed = breedsList.isNotEmpty ? breedsList.first : null;
      });
    } else {
      setState(() {
        breedsList = [];
        selectedBreed = null;
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
              // decoration: BoxDecoration(
              //   borderRadius:BorderRadius.circular(12),
              //   border: Border.all(color: Colors.grey)
              // ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _showPetDialog,
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
                          onSelected: (_) =>
                              setState(() => selectedCategory = c),
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
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên thú cưng...',
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: petsCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyState(
                    label: 'No categories found',
                    icon: Icons.pets_outlined,
                  );
                }
                var pets = snapshot.data!.docs
                    .map((doc) => Pet.fromDocument(doc))
                    .toList();

                // Search by name
                if (_searchQuery.isNotEmpty) {
                  pets = pets
                      .where((p) => p.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                // Filter by category
                if (selectedCategory != 'All') {
                  pets = pets
                      .where((p) => p.category == selectedCategory)
                      .toList();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        constraints.maxWidth ~/ 320; // ~320px mỗi card
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount.clamp(1, 5),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3 / 2,
                      ),
                      itemCount: pets.length,
                      itemBuilder: (context, i) => PetCard(
                        pet: pets[i],
                        onEdit: () => _showPetDialog(pet: pets[i]),
                        onDelete: () => _confirmDelete(pets[i].id),
                        onTap: () => _showPetDetailsDialog(pets[i]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 8),
                  Text('Đang xử lý...',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final l10n = AppLocalizations.of(context)!;
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
    if (ok == true) deletePet(id);
  }

  void _showPetDialog({Pet? pet}) async {
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
    bool isAvailable = pet?.isAvailable ?? false;

    if (pet != null) {
      await loadBreeds(pet.category);
      // Inject pet.breed if not in list and not empty
      if (pet.breed.isNotEmpty && !breedsList.contains(pet.breed)) {
        breedsList = [...breedsList, pet.breed];
      }
      // Deduplicate while preserving order
      final seen = <String>{};
      breedsList = breedsList.where((b) => seen.add(b)).toList();
      selectedBreed = pet.breed.isNotEmpty ? pet.breed : null;
      selectedColor = (pet.color != null && colorKeys.contains(pet.color)) ? pet.color : null; // Khởi tạo màu sắc hiện tại (an toàn)
    } else {
      await loadBreeds(pickedCategory);
      // Deduplicate list just in case
      final seen = <String>{};
      breedsList = breedsList.where((b) => seen.add(b)).toList();
      selectedColor = null; // Reset màu sắc cho pet mới
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
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
      final colorValue = (selectedColor != null && colorKeys.contains(selectedColor))
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
                                  TextFormField(
                                    controller: nameController,
                                    decoration: _input('Name',
                                        prefix:
                                            const Icon(Icons.badge_outlined)),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Vui lòng nhập tên thú cưng';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: pickedCategory,
                                    decoration: _input('Category',
                                        prefix: const Icon(
                                            Icons.category_outlined)),
                                    onChanged: (v) async {
                                      setStateDialog(() {
                                        pickedCategory = v!;
                                        selectedBreed = null;
                                        breedsList = [];
                                      });
                                      await loadBreeds(pickedCategory);
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
                                      decoration: _input('Breed',
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
                                    decoration: _input('Price',
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
                                    decoration: _input('Weight (kg)',
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
                                    decoration: _input('Age',
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
                                    decoration: _input('Gender',
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
                                    items: colorKeys
                                        .map((colorKey) => DropdownMenuItem(
                                            value: colorKey,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: _getColorFromKey(
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
                                                Text(_getLocalizedColor(
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
                                      Text('Available for Sale',
                                          style: TextStyle(fontSize: 16)),
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
                                    decoration: _input('About',
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
                                          'Vui lòng chọn ảnh',
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
                    if (isLoading) return; // prevent double taps
                    if (!formKey.currentState!.validate()) {
                      debugPrint('Form validation failed');
                      return;
                    }
                    debugPrint('Form validation passed');

                    // Additional validations
                    if (selectedBreed == null || selectedBreed!.isEmpty) {
                      debugPrint('Breed validation failed: $selectedBreed');
                      _snack('Vui lòng chọn giống!');
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

                    if (pet == null) {
                      debugPrint('Adding new pet...');
                      await addPet(newPet); // ensure upload finishes before clearing bytes
                    } else {
                      debugPrint('Updating existing pet...');
                      await updatePet(newPet); // optional await for consistency
                    }

                    if (!mounted) return;
                    Navigator.pop(context); // _imageBytes already cleared in add/update finally
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Text(
            pet.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: 300,
                          height: 300,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Image.network(
                              pet.imageUrl,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image,
                                      size: 56, color: Colors.grey),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoRow(Icons.category, 'Category', pet.category),
                    _infoRow(Icons.pets, 'Breed', pet.breed),
                    _infoRow(Icons.price_change, 'Price',
                        CurrencyHelper.formatVND(pet.price ?? pet.weight)),
                    _infoRow(Icons.cake, 'Age', '${pet.age} years'),
                    _infoRow(Icons.male, 'Gender', pet.gender),
                    if (pet.color != null)
                      _infoRowWithColor(Icons.palette, l10n.color, pet.color!),
                    _infoRow(
                        Icons.monitor_weight, 'Weight', '${pet.weight} Kg'),
                    const SizedBox(height: 10),
                    Text(l10n.about,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SelectableText(
                      pet.about,
                      textAlign: TextAlign.justify,
                      // maxLines: 12, overflow: TextOverflow.ellipsis, // bật nếu muốn cắt bớt
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close, style: const TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$title: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithColor(IconData icon, String title, String colorKey) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$title: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _getColorFromKey(colorKey),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getLocalizedColor(l10n, colorKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods cho màu sắc
  Color _getColorFromKey(String colorKey) {
    switch (colorKey) {
      case 'colorBrown':
        return Colors.brown;
      case 'colorBlack':
        return Colors.black;
      case 'colorWhite':
        return Colors.white;
      case 'colorGray':
        return Colors.grey;
      case 'colorGolden':
        return Colors.amber;
      case 'colorCream':
        return const Color(0xFFF5DEB3);
      case 'colorOrange':
        return Colors.orange;
      case 'colorBlue':
        return Colors.blue;
      case 'colorGreen':
        return Colors.green;
      case 'colorRed':
        return Colors.red;
      case 'colorMixed':
        return Colors.grey.shade400;
      default:
        return Colors.grey;
    }
  }

  String _getLocalizedColor(AppLocalizations l10n, String colorKey) {
    switch (colorKey) {
      case 'colorBrown':
        return l10n.colorBrown;
      case 'colorBlack':
        return l10n.colorBlack;
      case 'colorWhite':
        return l10n.colorWhite;
      case 'colorGray':
        return l10n.colorGray;
      case 'colorGolden':
        return l10n.colorGolden;
      case 'colorCream':
        return l10n.colorCream;
      case 'colorOrange':
        return l10n.colorOrange;
      case 'colorBlue':
        return l10n.colorBlue;
      case 'colorGreen':
        return l10n.colorGreen;
      case 'colorRed':
        return l10n.colorRed;
      case 'colorMixed':
        return l10n.colorMixed;
      default:
        return colorKey;
    }
  }
}
