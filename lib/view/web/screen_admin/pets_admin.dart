import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../model/pet_model.dart';

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
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Dogs', 'Cats', 'Fish', 'Birds'];
  bool isLoading = false;

  List<String> breedsList = [];
  String? selectedBreed;

  final List<String> genderOptions = ['Male', 'Female'];

  //Save to Storage
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      // Lấy extension từ fileName hoặc mặc định là jpg
      String ext = 'jpg';
      if (fileName.contains('.')) {
        ext = fileName.split('.').last.toLowerCase();
      }
      // Nếu fileName không có đuôi, thêm đuôi phù hợp
      String finalFileName = fileName.contains('.') ? fileName : '$fileName.$ext';
      // Xác định contentType
      String contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';
      else if (ext == 'gif') contentType = 'image/gif';
      else if (ext == 'bmp') contentType = 'image/bmp';
      else if (ext == 'webp') contentType = 'image/webp';

      final metadata = SettableMetadata(contentType: contentType);
      Reference storageRef = FirebaseStorage.instance.ref().child(finalFileName);
      UploadTask uploadTask = storageRef.putData(imageBytes, metadata);
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

        _fileName = "uploaded_image.${extension ?? 'jpg'}";

        print("✅ Image picked: ${_imageBytes!.length} bytes, File: $_fileName");
      });
    } else {
      print("No image selected");
    }
  }

  void addPet(Pet pet) async {
    setState(() => isLoading = true);
    // Tự động sinh id nếu chưa có
    String newId = pet.id.isNotEmpty ? pet.id : const Uuid().v4();
    // Kiểm tra trùng id
    final existing = await petsCollection.doc(newId).get();
    if (existing.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID đã tồn tại, vui lòng thử lại!')),
      );
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
      final uri = Uri.parse('http://localhost:5000/train');
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        print('Train thành công!');
      } else {
        print('Train thất bại: ${response.statusCode}');
      }
    } catch (e) {
      print('Lỗi train: $e');
    }
  }

  void updatePet(Pet pet) async {
    setState(() => isLoading = true);

    if (_imageBytes != null) {
      try {
        final oldImageRef = FirebaseStorage.instance.refFromURL(pet.imageUrl);
        await oldImageRef.delete();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Xóa hình cũ bị lỗi $e")));
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
        final imageRed = FirebaseStorage.instance.refFromURL(imageUrl);
        await imageRed.delete();
      }
      await petsCollection.doc(id).delete();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Xóa thú cưng hoặc hình $e")));
    }

    setState(() => isLoading = false);
  }

  Future<void> addBreed(String category, String newBreed) async {
    final docRef =
        await FirebaseFirestore.instance.collection('Breed').doc(category);
    final doc = await docRef.get();
    if (doc.exists) {
      {
        docRef.update({
          'breeds': FieldValue.arrayUnion([newBreed]),
        });
      }
    } else {
      // Nếu tài liệu chưa tồn tại, tạo mới và thêm mảng chứa giống mới
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
      {
        final doc = querySnapshot.docs.first;
        setState(() {
          breedsList = List<String>.from(doc['breeds']);
          selectedBreed = breedsList.isNotEmpty ? breedsList.first : null;
        });
      }
    } else {
      setState(() {
        breedsList = [];
        selectedBreed = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Manage Pets'),
            const SizedBox(
              width: 20,
            ),
            GestureDetector(
              onTap: () {
                _showPetDialog();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 5,
                    ),
                    Center(
                      child: Text(
                        "Create New",
                        style: TextStyle(fontSize: 16),
                      ),
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
        ),
        actions: [
          DropdownButton<String>(
            value: selectedCategory,
            onChanged: (String? newValue) {
              setState(() {
                selectedCategory = newValue!;
              });
            },
            items: categories.map<DropdownMenuItem<String>>((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder(
            stream: petsCollection.snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No pets available'));
              }
              var pets = snapshot.data!.docs
                  .map((doc) => Pet.fromDocument(doc))
                  .toList();
              if (selectedCategory != 'All') {
                pets = pets
                    .where((pet) => pet.category == selectedCategory)
                    .toList();
              }

              return ListView.builder(
                itemCount: pets.length,
                itemBuilder: (context, index) {
                  Pet pet = pets[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(pet.imageUrl,
                            width: 60, height: 60, fit: BoxFit.cover),
                      ),
                      title: Text(pet.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${pet.breed} - \$ ${pet.weight}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                              onPressed: () => _showPetDialog(pet: pet)),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Xác nhận'),
                                    content: const Text(
                                        'Bạn có chắc chắn muốn xóa thú cưng này không?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Hủy'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text(
                                          'Xóa',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          deletePet(pet.id);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () => _showPetDetailsDialog(pet),
                    ),
                  );
                },
              );
            },
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showPetDialog({Pet? pet}) async {
    final nameController = TextEditingController(text: pet?.name);
    final imageController = TextEditingController(text: pet?.imageUrl);
    final ageController = TextEditingController(text: pet?.age);
    final aboutController = TextEditingController(text: pet?.about);
    final genderController = TextEditingController(text: pet?.gender);
    final weightController = TextEditingController(text: pet?.weight);

    String selectedCategory = pet?.category ?? 'Dogs';

    if (pet != null) {
      await loadBreeds(pet.category);
      selectedBreed = pet.breed;
    } else {
      await loadBreeds(selectedCategory);
    }
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(pet == null ? 'Add Pet' : 'Edit Pet'),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name',border: OutlineInputBorder(),)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        onChanged: (String? newValue) async {
                          setStateDialog(() {
                            selectedCategory = newValue!;
                            selectedBreed = null;
                            breedsList = [];
                          });
                          await loadBreeds(selectedCategory);
                          setStateDialog(() {});
                        },
                        items: categories.sublist(1).map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      if (breedsList.isNotEmpty)
                        SizedBox(
                          width: 500,
                          child: DropdownButtonFormField<String>(
                            value: selectedBreed,
                            onChanged: (String? value) {
                              setStateDialog(() {
                                selectedBreed = value!;
                              });
                            },
                            items: breedsList.map((String breed) {
                              return DropdownMenuItem<String>(
                                value: breed,
                                child: Text(breed),
                              );
                            }).toList(),
                            decoration:
                                const InputDecoration(labelText: 'Breed'),
                          ),
                        ),
                      const SizedBox(
                        height: 20,
                      ),
                      pet != null
                          ? _imageBytes == null
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(imageController.text,
                                        height: 150, fit: BoxFit.cover),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                      onPressed: () async {
                                        await _pickImage();
                                        setStateDialog(() {});
                                      },
                                      child: const Icon(
                                        Icons.edit,
                                        size: 25,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Image.memory(_imageBytes!,
                                  height: 100, fit: BoxFit.cover)
                          : ElevatedButton(
                              onPressed: () async {
                                await _pickImage();
                                setStateDialog(() {});
                              },
                              child: const Text("Pick Image"),
                            ),
                      const SizedBox(height: 10),
                      _imageBytes != null && pet == null
                          ? Image.memory(
                              _imageBytes!,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : const Text(""),
                      const SizedBox(height: 10),
                      TextField(
                          controller: weightController,
                          decoration: const InputDecoration(labelText: 'Price',border: OutlineInputBorder(),)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: ageController,
                          decoration: const InputDecoration(labelText: 'Age',border: OutlineInputBorder(),)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: aboutController,
                          maxLines: null,
                          decoration: const InputDecoration(labelText: 'About',border: OutlineInputBorder(),)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: genderController.text.isNotEmpty ? genderController.text : null,
                        onChanged: (String? newValue) {
                          setStateDialog(() {
                            genderController.text = newValue ?? '';
                          });
                        },
                        items: genderOptions.map((String gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Gender'),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Kiểm tra dữ liệu đầu vào
                    if (nameController.text.trim().isEmpty ||
                        selectedCategory.isEmpty ||
                        ageController.text.trim().isEmpty ||
                        selectedBreed == null ||
                        aboutController.text.trim().isEmpty ||
                        genderController.text.trim().isEmpty ||
                        weightController.text.trim().isEmpty ||
                        (_imageBytes == null && (pet == null || imageController.text.isEmpty))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin và chọn ảnh!')),
                      );
                      return;
                    }
                    // Kiểm tra số
                    if (double.tryParse(weightController.text.trim()) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Giá phải là số!')),
                      );
                      return;
                    }
                    if (double.tryParse(weightController.text.trim())! <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Giá phải lớn hơn 0!')),
                      );
                      return;
                    }
                    if (int.tryParse(ageController.text.trim()) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tuổi phải là số nguyên!')),
                      );
                      return;
                    }
                    String imageUrl = imageController.text;
                    String petId = pet?.id ?? const Uuid().v4();
                    if (_imageBytes != null) {
                      imageUrl = await uploadImage(_imageBytes!, petId);
                      if (imageUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lỗi upload ảnh!')),
                        );
                        return;
                      }
                    }
                    final newPet = Pet(
                      id: petId,
                      name: nameController.text,
                      category: selectedCategory,
                      imageUrl: imageUrl,
                      age: ageController.text,
                      breed: selectedBreed ?? '',
                      about: aboutController.text,
                      gender: genderController.text,
                      weight: weightController.text,
                    );
                    if (pet == null) {
                      addPet(newPet); // Chỉ gọi train khi thêm mới
                    } else {
                      updatePet(newPet);
                    }
                    Navigator.pop(context);
                    _imageBytes = null;
                  },
                  child: Text(pet == null ? 'Add' : 'Update'),
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
      builder: (context) {
        return AlertDialog(
          title: Text(
            pet.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        pet.imageUrl,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _infoRow(Icons.category, "Category", pet.category),
                  _infoRow(Icons.pets, "Breed", pet.breed),
                  _infoRow(Icons.monitor_weight, "Price", "\$ ${pet.weight} "),
                  _infoRow(Icons.cake, "Age", "${pet.age} years"),
                  _infoRow(Icons.male, "Gender", pet.gender),
                  _infoRow(Icons.monitor_weight, "Weight", "${pet.weight} Kg"),
                  const SizedBox(height: 10),
                  const Text(
                    "About:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    pet.about,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontSize: 16)),
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
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "$title: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _showDialogAddBreed(String selectedCategory) {
    showDialog(
        context: context,
        builder: (context) {
          TextEditingController newBreedController = TextEditingController();
          return AlertDialog(
            title: const Text("New Breed"),
            content: TextField(
              controller: newBreedController,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Hủy"),
              ),
              TextButton(
                onPressed: () {
                  addBreed(selectedCategory, newBreedController.text);
                  Navigator.pop(context);
                },
                child: const Text("Lưu"),
              ),
            ],
          );
        });
  }
}
