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
import '../../model/pet_model.dart';

import 'components/pet_card.dart';

class PetsAdmin extends StatefulWidget {
  const PetsAdmin({super.key});

  @override
  State<PetsAdmin> createState() => _PetsState();
}

class _PetsState extends State<PetsAdmin> {
  Uint8List? _imageBytes;
  String? _fileName;

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

  // ===== Storage =====
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      String ext = 'jpg';
      if (fileName.contains('.')) {
        ext = fileName.split('.').last.toLowerCase();
      }
      final finalFileName =
          fileName.contains('.') ? fileName : '$fileName.$ext';
      String contentType = 'image/jpeg';
      if (ext == 'png')
        contentType = 'image/png';
      else if (ext == 'gif')
        contentType = 'image/gif';
      else if (ext == 'bmp')
        contentType = 'image/bmp';
      else if (ext == 'webp') contentType = 'image/webp';

      final metadata = SettableMetadata(contentType: contentType);
      final storageRef = FirebaseStorage.instance.ref().child(finalFileName);
      final uploadTask = storageRef.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint(e.toString());
      return "";
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        final ext = result.files.first.extension;
        _fileName = "uploaded_image.${ext ?? 'jpg'}";
      });
    }
  }

  // ===== CRUD =====
  void addPet(Pet pet) async {
    setState(() => isLoading = true);
    final newId = pet.id.isNotEmpty ? pet.id : const Uuid().v4();
    final existing = await petsCollection.doc(newId).get();
    if (existing.exists) {
      _snack('ID đã tồn tại, vui lòng thử lại!');
      setState(() => isLoading = false);
      return;
    }
    await petsCollection.doc(newId).set({
      'id': newId,
      'name': pet.name,
      'category': pet.category,
      'imageUrl': pet.imageUrl,
      'age': pet.age,
      'breed': pet.breed,
      'about': pet.about,
      'sex': pet.gender,
      'weight': pet.weight,
    });
    callTrainAPI();
    setState(() => isLoading = false);
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

  void updatePet(Pet pet) async {
    setState(() => isLoading = true);

    if (_imageBytes != null) {
      try {
        final oldImageRef = FirebaseStorage.instance.refFromURL(pet.imageUrl);
        await oldImageRef.delete();
      } catch (e) {
        _snack('Xóa hình cũ bị lỗi $e');
      }
    }
    await petsCollection.doc(pet.id).update({
      'name': pet.name,
      'category': pet.category,
      'imageUrl': pet.imageUrl,
      'age': pet.age,
      'breed': pet.breed,
      'about': pet.about,
      'sex': pet.gender,
      'weight': pet.weight,
    });
    setState(() => isLoading = false);
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
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
                style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor)),
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
                icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                label: Text(l10n.addPet,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                          backgroundColor: Theme.of(context).chipTheme.backgroundColor,
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
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
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
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 8),
                  Text('Đang xử lý...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
              child: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (ok == true) deletePet(id);
  }

  void _showPetDialog({Pet? pet}) async {
    final nameController = TextEditingController(text: pet?.name);
    final imageController = TextEditingController(text: pet?.imageUrl);
    final ageController = TextEditingController(text: pet?.age);
    final aboutController = TextEditingController(text: pet?.about);
    final genderController = TextEditingController(text: pet?.gender);
    final weightController = TextEditingController(text: pet?.weight);

    String pickedCategory = pet?.category ?? 'Dogs';

    if (pet != null) {
      await loadBreeds(pet.category);
      selectedBreed = pet.breed;
    } else {
      await loadBreeds(pickedCategory);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(pet == null ? l10n.addPet : l10n.edit),
              content: SingleChildScrollView(
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
                                TextField(
                                  controller: nameController,
                                  decoration: _input('Name',
                                      prefix: const Icon(Icons.badge_outlined)),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: pickedCategory,
                                  decoration: _input('Category',
                                      prefix:
                                          const Icon(Icons.category_outlined)),
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
                                    value: selectedBreed,
                                    decoration: _input('Breed',
                                        prefix:
                                            const Icon(Icons.pets_outlined)),
                                    onChanged: (v) =>
                                        setStateDialog(() => selectedBreed = v),
                                    items: breedsList
                                        .map((e) => DropdownMenuItem(
                                            value: e, child: Text(e)))
                                        .toList(),
                                  ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: weightController,
                                  decoration: _input('Price',
                                      prefix: const Icon(Icons.attach_money)),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: ageController,
                                  decoration: _input('Age',
                                      prefix: const Icon(Icons.cake_outlined)),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: genderController.text.isNotEmpty
                                      ? genderController.text
                                      : null,
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
                                            color:
                                                primaryColor.withOpacity(.25)),
                                      ),
                                      child: _imageBytes != null
                                          ? FittedBox(
                                              fit: BoxFit.contain,
                                              // hiển thị nguyên hình
                                              child: Image.memory(_imageBytes!),
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
                                        icon: const Icon(
                                            Icons.photo_library_outlined),
                                        onPressed: () async {
                                          await _pickImage();
                                          setStateDialog(() {});
                                        },
                                        label: Text(l10n.pickImage),
                                      ),
                                    ),
                                    if (pet != null && _imageBytes != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Clear',
                                        onPressed: () {
                                          setStateDialog(
                                              () => _imageBytes = null);
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                    ],
                                  ],
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _imageBytes = null;
                  },
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () async {
                    // Validate
                    if (nameController.text.trim().isEmpty ||
                        pickedCategory.isEmpty ||
                        ageController.text.trim().isEmpty ||
                        selectedBreed == null ||
                        aboutController.text.trim().isEmpty ||
                        genderController.text.trim().isNotEmpty &&
                            !genderOptions.contains(genderController.text) ||
                        weightController.text.trim().isEmpty ||
                        (_imageBytes == null &&
                            (pet == null || imageController.text.isEmpty))) {
                      _snack('Vui lòng nhập đầy đủ thông tin và chọn ảnh!');
                      return;
                    }
                    if (double.tryParse(weightController.text.trim()) == null) {
                      _snack('Giá phải là số!');
                      return;
                    }
                    if (double.parse(weightController.text.trim()) <= 0) {
                      _snack('Giá phải lớn hơn 0!');
                      return;
                    }
                    if (int.tryParse(ageController.text.trim()) == null) {
                      _snack('Tuổi phải là số nguyên!');
                      return;
                    }

                    String imageUrl = imageController.text;
                    final petId = pet?.id ?? const Uuid().v4();
                    if (_imageBytes != null) {
                      imageUrl = await uploadImage(_imageBytes!, petId);
                      if (imageUrl.isEmpty) {
                        _snack('Lỗi upload ảnh!');
                        return;
                      }
                    }

                    final newPet = Pet(
                      id: petId,
                      name: nameController.text,
                      category: pickedCategory,
                      imageUrl: imageUrl,
                      age: ageController.text,
                      breed: selectedBreed ?? '',
                      about: aboutController.text,
                      gender: genderController.text,
                      weight: weightController.text,
                    );

                    if (pet == null) {
                      addPet(newPet);
                    } else {
                      updatePet(newPet);
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                    _imageBytes = null;
                  },
                  child: Text(pet == null ? l10n.addPet : l10n.save,
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
                                          color: Theme.of(context).colorScheme.primary)),
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
                    _infoRow(Icons.price_change, 'Price', '\$ ${pet.weight}'),
                    _infoRow(Icons.cake, 'Age', '${pet.age} years'),
                    _infoRow(Icons.male, 'Gender', pet.gender),
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
}
