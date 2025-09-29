// Test để kiểm tra dữ liệu Categories trong Firebase
import 'package:cloud_firestore/cloud_firestore.dart';

void testFirebaseData() async {
  final firestore = FirebaseFirestore.instance;

  print('=== Testing Firebase Categories Data ===\n');

  try {
    final snapshot = await firestore.collection('Category').get();

    print('Total categories found: ${snapshot.docs.length}');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      print('\nCategory ID: ${doc.id}');
      print('Name: ${data['name']}');
      print('Breeds: ${data['breeds']}');

      // Test search cho "do"
      final categoryName = (data['name'] as String? ?? '').toLowerCase();
      if (categoryName.contains('do')) {
        print('✅ This category matches "do" search: $categoryName');
      }

      // Test search cho breeds
      final breeds = data['breeds'] as List<dynamic>? ?? [];
      for (var breed in breeds) {
        final breedName = (breed as String? ?? '').toLowerCase();
        if (breedName.contains('do') || breedName.contains('golden')) {
          print('✅ Breed matches search: $breed');
        }
      }
    }

    // Test với queries cụ thể
    final testQueries = ['do', 'dogs', 'dog', 'golden', 'poodle'];

    for (String query in testQueries) {
      print('\n--- Testing query: "$query" ---');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final categoryName = (data['name'] as String? ?? '').toLowerCase();

        if (categoryName.contains(query.toLowerCase())) {
          print('Category match: ${data['name']}');
        }

        final breeds = data['breeds'] as List<dynamic>? ?? [];
        for (var breed in breeds) {
          final breedName = (breed as String? ?? '').toLowerCase();
          if (breedName.contains(query.toLowerCase())) {
            print('Breed match: $breed (from ${data['name']})');
          }
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

// Gọi hàm test trong initState của SearchPage
// _testFirebaseData();
