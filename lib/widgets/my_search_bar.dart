import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MySearchBar extends StatelessWidget {
  final Function(String) onSearch;
  final Function(File) onImageSearch;

  const MySearchBar({super.key, required this.onSearch, required this.onImageSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              spreadRadius: 3,
              offset: Offset(0, 5),
            )
          ]),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                hintText: "Search for items here",
                hintStyle: const TextStyle(
                  color: Colors.black45,
                ),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                onImageSearch(File(pickedFile.path));
              }
            },
            child: const Icon(Icons.camera_alt, color: Colors.blue, size: 25),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}
