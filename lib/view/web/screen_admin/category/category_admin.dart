import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/utils/contants.dart';

import '../../components/empty_state.dart';
import 'components/category_card.dart';

class CategoryAdmin extends StatefulWidget {
  const CategoryAdmin({super.key});

  @override
  State<CategoryAdmin> createState() => _CategoryAdminState();
}

class _CategoryAdminState extends State<CategoryAdmin> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Uint8List? _imageBytes;
  String? _fileName;
  bool _loading = false;
  String _searchQuery = '';

  // ===== Storage =====
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      // lấy extension nếu có
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
      final storageRef =
          FirebaseStorage.instance.ref().child('categories/$finalFileName');
      final uploadTask = storageRef.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint(e.toString());
      return '';
    }
  }

  // ===== Pick image =====
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        final ext = result.files.first.extension;
        _fileName = 'uploaded_image.${ext ?? 'jpg'}';
      });
    }
  }

  Future<void> deleteImageFromStorage(String imageUrl) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.deleteSuccessfully)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ảnh không tồn tại hoặc lỗi: $e')));
    }
  }

  // ===== Breed helpers =====
  Future<void> addBreed(String categoryId, String newBreed) async {
    await _firestore.collection('Category').doc(categoryId).update({
      'breeds': FieldValue.arrayUnion([newBreed]),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã thêm giống mới')));
  }

  Future<void> deleteBreed(String categoryId, String breed) async {
    await _firestore.collection('Category').doc(categoryId).update({
      'breeds': FieldValue.arrayRemove([breed]),
    });
  }

  Future<void> editBreed(
      String categoryId, String oldBreed, String newBreed) async {
    final docRef = _firestore.collection('Category').doc(categoryId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final currentBreeds = List<String>.from(snapshot['breeds']);
      final index = currentBreeds.indexOf(oldBreed);
      if (index != -1) {
        currentBreeds[index] = newBreed;
        await docRef.update({'breeds': currentBreeds});
      }
    }
  }

  void _showBreedDialog(String categoryId, String name, List<String> breeds) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.breedOf(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.addBreed,
                    icon: const Icon(Icons.add_circle_outline,
                        color: primaryColor),
                    onPressed: () {
                      _showDialogAddBreed(categoryId, () async {
                        final updatedDoc = await _firestore
                            .collection('Category')
                            .doc(categoryId)
                            .get();
                        final updatedBreeds =
                            List<String>.from(updatedDoc['breeds']);
                        setStateDialog(() {
                          breeds
                            ..clear()
                            ..addAll(updatedBreeds);
                        });
                      }, null);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 360,
                child: breeds.isEmpty
                    ? Center(child: Text(AppLocalizations.of(context)!.noBreeds))
                    : ListView.separated(
                        primary: false,
                        shrinkWrap: true,
                        itemCount: breeds.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => ListTile(
                          title: Text(breeds[i]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showDialogAddBreed(categoryId, () async {
                                    final updatedDoc = await _firestore
                                        .collection('Category')
                                        .doc(categoryId)
                                        .get();
                                    final updatedBreeds =
                                        List<String>.from(updatedDoc['breeds']);
                                    setStateDialog(() {
                                      breeds
                                        ..clear()
                                        ..addAll(updatedBreeds);
                                    });
                                  }, breeds[i]);
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await deleteBreed(categoryId, breeds[i]);
                                  final updatedDoc = await _firestore
                                      .collection('Category')
                                      .doc(categoryId)
                                      .get();
                                  final updatedBreeds =
                                      List<String>.from(updatedDoc['breeds']);
                                  setStateDialog(() {
                                    breeds
                                      ..clear()
                                      ..addAll(updatedBreeds);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDialogAddBreed(
      String categoryId, VoidCallback refreshDialog, String? oldBreed) {
    final TextEditingController _newBreed =
        TextEditingController(text: oldBreed ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Text(oldBreed == null ? AppLocalizations.of(context)!.addNewBreed : AppLocalizations.of(context)!.editBreed),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              controller: _newBreed,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: AppLocalizations.of(context)!.breedName,
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () async {
                final newBreed = _newBreed.text.trim();
                if (newBreed.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppLocalizations.of(context)!.enterBreedName)));
                  return;
                }
                if (oldBreed == null) {
                  await addBreed(categoryId, newBreed);
                } else {
                  await editBreed(categoryId, oldBreed, newBreed);
                }
                if (!mounted) return;
                Navigator.pop(context);
                refreshDialog();
              },
              child: Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  // Add/Edit category dialog
  void _showCategoryDialog(
      {String? id, String? initialName, String? initialImageUrl}) {
    _nameController.text = initialName ?? '';
    _imageUrlController.text = initialImageUrl ?? '';
    _imageBytes = null; // reset preview bytes khi mở dialog mới

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              title: Text(id == null ? AppLocalizations.of(context)!.addCategory : AppLocalizations.of(context)!.editCategory),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.categoryName,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.image,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          color: secondaryColor,
                          child: _imageBytes != null
                              ? FittedBox(
                                  fit: BoxFit.contain,
                                  child: Image.memory(_imageBytes!))
                              : (_imageUrlController.text.isNotEmpty
                                  ? FittedBox(
                                      fit: BoxFit.contain,
                                      child: Image.network(
                                          _imageUrlController.text))
                                  : const Center(
                                      child: Icon(Icons.image_outlined,
                                          size: 48))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined),
                            onPressed: () async {
                              await _pickImage();
                              setStateDialog(() {});
                            },
                            label: const Text('Pick Image'),
                          ),
                          const SizedBox(width: 8),
                          if (_imageBytes != null)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setStateDialog(() => _imageBytes = null);
                              },
                              label: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel)),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(AppLocalizations.of(context)!.pleaseEnterCategoryName)));
                      return;
                    }

                    setState(() => _loading = true);
                    String imageUrl = _imageUrlController.text;

                    if (id == null && _imageBytes == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectImage)));
                      setState(() => _loading = false);
                      return;
                    }

                    if (_imageBytes != null) {
                      imageUrl = await uploadImage(
                          _imageBytes!, _nameController.text.trim());
                      if (imageUrl.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.imageUploadError)));
                        setState(() => _loading = false);
                        return;
                      }
                    }

                    final data = {
                      'name': _nameController.text.trim(),
                      'imageUrl': imageUrl
                    };

                    if (id == null) {
                      await _firestore
                          .collection('Category')
                          .add({...data, 'breeds': []});
                    } else {
                      await _firestore
                          .collection('Category')
                          .doc(id)
                          .update(data);
                    }

                    if (!mounted) return;
                    setState(() => _loading = false);
                    Navigator.pop(context);
                  },
                  child:
                      Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Xóa danh mục
  Future<void> _deleteCategory(String id, String imageUrl) async {
    await _firestore.collection('Category').doc(id).delete();
    await deleteImageFromStorage(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Row(
          children: [
            Text(AppLocalizations.of(context)!.manageCategories, 
                style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor)),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: Theme.of(context).primaryColor,
              ),
              onPressed: () => _showCategoryDialog(),
              icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
              label: Text(AppLocalizations.of(context)!.createNew,
                  style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        ),
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
                  hintText: AppLocalizations.of(context)!.searchCategories,
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
              stream: _firestore.collection('Category').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyState(
                    label: AppLocalizations.of(context)!.noCategoriesFound,
                    icon: Icons.category_outlined,
                  );
                }

                var docs = snapshot.data!.docs;
                // Search by name
                if (_searchQuery.isNotEmpty) {
                  docs = docs
                      .where((d) => (d['name'] as String)
                          .toLowerCase()
                          .contains(_searchQuery))
                      .toList();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        (constraints.maxWidth ~/ 320).clamp(1, 5);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 4 / 3,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final id = doc.id;
                        final name = doc['name'] as String;
                        final imageUrl = doc['imageUrl'] as String;
                        final breeds = List<String>.from(doc['breeds'] ?? []);

                        return CategoryCard(
                          name: name,
                          imageUrl: imageUrl,
                          breedCount: breeds.length,
                          onEdit: () => _showCategoryDialog(
                              id: id,
                              initialName: name,
                              initialImageUrl: imageUrl),
                          onDelete: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Xác nhận'),
                                content: const Text(
                                    'Bạn có chắc muốn xoá danh mục này?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Hủy')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('Xóa',
                                          style: TextStyle(color: Theme.of(context).colorScheme.error))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _deleteCategory(id, imageUrl);
                            }
                          },
                          onManageBreeds: () =>
                              _showBreedDialog(id, name, breeds),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_loading)
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
}
