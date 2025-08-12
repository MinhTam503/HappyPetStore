import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class CategoryAdmin extends StatefulWidget {
  const CategoryAdmin({super.key});

  @override
  State<CategoryAdmin> createState() => _CategoryAdminState();
}

class _CategoryAdminState extends State<CategoryAdmin> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Uint8List? _imageBytes;
  String? _fileName;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //Save to Storage
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      Reference storageRef =
          FirebaseStorage.instance.ref().child("$fileName.jpg");
      UploadTask uploadTask = storageRef.putData(imageBytes);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(e.toString());
      return "";
    }
  }

  //Pick image
  Future<void> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        String? extension = result.files.first.extension;
        // Nếu không có extension, mặc định là png
        _fileName = "uploaded_image.${extension ?? 'png'}";

        print("✅ Image picked: ${_imageBytes!.length} bytes, File: $_fileName");
      });
    } else {
      print("No image selected");
    }
  }

  Future<void> deleteImageFromStorage(String imageUrl) async {
    try {
      Reference ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Delete successfully"),
        ),
      );
    } catch (e) {
      if (e.toString() ==
          "url could not be parsed, ensure it's a valid storage url") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ảnh không tồn tại"),
          ),
        );
      }
      print(e.toString());
    }
  }

  Future<void> addBreed(String categoryId, String newBreed) async {
    DocumentReference docRef =
        _firestore.collection('Category').doc(categoryId);
    await docRef.update({
      'breeds': FieldValue.arrayUnion([newBreed]),
    });
    await ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Đã thêm thành công")));
  }

  Future<void> deleteBreed(String categoryId, String breed) async {
    DocumentReference docRef =
        _firestore.collection('Category').doc(categoryId);
    await docRef.update({
      'breeds': FieldValue.arrayRemove([breed]),
    });
  }

  Future<void> editBreed(
      String categoryId, String oldBreed, String newBreed) async {
    DocumentReference docRef =
        _firestore.collection("Category").doc(categoryId);
    DocumentSnapshot snapshot = await docRef.get();
    if (snapshot.exists) {
      List<String> currentBreeds = List<String>.from(snapshot['breeds']);
      int index = currentBreeds.indexOf(oldBreed);
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
          return StatefulBuilder(builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  Text("Breed of " + name),
                  const SizedBox(
                    width: 10,
                  ),
                  GestureDetector(
                    child: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      _showDialogAddBreed(categoryId, () async {
                        DocumentSnapshot updatedDoc = await _firestore
                            .collection('Category')
                            .doc(categoryId)
                            .get();
                        List<String> updatedBreeds =
                            List<String>.from(updatedDoc['breeds']);
                        setStateDialog(() {
                          breeds.clear();
                          breeds.addAll(updatedBreeds);
                        });
                      }, null);
                    },
                  )
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 250,
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: breeds.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Row(
                          children: [
                            Text(breeds[index]),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                _showDialogAddBreed(categoryId, () async {
                                  DocumentSnapshot updatedDoc = await _firestore
                                      .collection('Category')
                                      .doc(categoryId)
                                      .get();
                                  List<String> updatedBreeds =
                                      List<String>.from(updatedDoc['breeds']);
                                  setStateDialog(() {
                                    breeds.clear();
                                    breeds.addAll(updatedBreeds);
                                  });
                                }, breeds[index]);
                              },
                              child: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            GestureDetector(
                              onTap: () async {
                                await deleteBreed(categoryId, breeds[index]);
                                DocumentSnapshot updatedDoc = await _firestore
                                    .collection("Category")
                                    .doc(categoryId)
                                    .get();
                                List<String> updatedBreeds =
                                    List<String>.from(updatedDoc['breeds']);
                                setStateDialog(() {
                                  breeds.clear();
                                  breeds.addAll(updatedBreeds);
                                });
                              },
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
              ),
            );
          });
        });
  }

  void _showDialogAddBreed(
      String categoryId, VoidCallback refreshDialog, String? oldBreed) {
    TextEditingController _newBreed = TextEditingController();
    if (oldBreed != null) {
      _newBreed.text = oldBreed;
    }

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: oldBreed == null
                ? const Text("Add New Breed")
                : const Text("Edit Breed"),
            content: oldBreed == null
                ? TextField(
                    controller: _newBreed,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Enter breed',
                    ),
                  )
                : TextField(
                    controller: _newBreed,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Name breed',
                    ),
                  ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    String newBreed = _newBreed.text.trim();
                    if (newBreed.isNotEmpty) {
                      if (oldBreed == null) {
                        await addBreed(categoryId, _newBreed.text);
                      } else {
                        await editBreed(categoryId, oldBreed, _newBreed.text);
                      }
                      Navigator.pop(context);
                      refreshDialog();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Please enter a breed name")),
                      );
                    }
                  },
                  child: oldBreed == null
                      ? const Text("Add")
                      : const Text("Update")),
            ],
          );
        });
  }

  // Hiển thị Dialog để thêm/chỉnh sửa danh mục
  void _showCategoryDialog(
      {String? id, String? initialName, String? initialImageUrl}) {
    _nameController.text = initialName ?? '';
    _imageUrlController.text = initialImageUrl ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(id == null ? "Add Category" : "Edit Category"),
            content: SingleChildScrollView(
              child: id != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: "Category Name"),
                        ),
                        const SizedBox(height: 10),
                        const Text("Image"),
                        const SizedBox(height: 10),
                        _imageUrlController.text.isNotEmpty
                            ? Column(
                                children: [
                                  _imageBytes == null
                                      ? Image.network(_imageUrlController.text,
                                          height: 100, fit: BoxFit.cover)
                                      : Image.memory(_imageBytes!,
                                          height: 100, fit: BoxFit.cover),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _pickImage();
                                      setStateDialog(() {});
                                    },
                                    child: const Text("Change Image"),
                                  )
                                ],
                              )
                            : const SizedBox(
                                height: 100,
                                child: Center(child: Text("No Image"))),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: "Category Name"),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            await _pickImage();
                            setStateDialog(() {});
                          },
                          child: const Text("Pick Image"),
                        ),
                        const SizedBox(height: 10),
                        _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox(
                                height: 100,
                                child: Center(child: Text("No Image"))),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  if (_nameController.text.trim().isEmpty ||
                      _imageBytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Vui lòng nhập đầy đủ thông tin và chọn ảnh!')),
                    );
                    return;
                  }
                  String name = _nameController.text.trim();
                  String imageUrl = await uploadImage(_imageBytes!, name);
                  if (imageUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lỗi upload ảnh!')),
                    );
                    return;
                  }
                  if (id == null) {
                    await _firestore
                        .collection('Category')
                        .add({'name': name, 'imageUrl': imageUrl});
                    _imageBytes = null;
                  } else {
                    await _firestore
                        .collection('Category')
                        .doc(id)
                        .update({'name': name, 'imageUrl': imageUrl});
                    _imageBytes = null;
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        });
      },
    );
  }

  // Xóa danh mục
  void _deleteCategory(String id) async {
    await _firestore.collection('Category').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Row(
        children: [
          const Text("Category Admin"),
          const SizedBox(
            width: 20,
          ),
          GestureDetector(
            onTap: () {
              _showCategoryDialog();
            },
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red)),
              child: const Row(
                children: [
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    "Create New",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Icon(Icons.add_circle),
                  SizedBox(
                    width: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Category').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No categories found"));
          }
          return ListView(
            padding: const EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              String id = doc.id;
              String name = doc['name'];
              String imageUrl = doc['imageUrl'];
              List<String> breeds = List<String>.from(doc['breeds']);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: Image.network(imageUrl,
                      width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showCategoryDialog(
                            id: id,
                            initialName: name,
                            initialImageUrl: imageUrl),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteCategory(id);
                          deleteImageFromStorage(imageUrl);
                          _imageBytes = null;
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    _showBreedDialog(id, name, breeds);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
