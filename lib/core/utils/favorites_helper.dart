import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to add createdAt timestamp to favorites
class FavoritesHelper {
  final FirebaseFirestore firestore;
  
  FavoritesHelper({required this.firestore});
  
  /// Add pet to favorites with createdAt timestamp
  Future<void> addToFavorites({
    required String userId,
    required String productId,
    required String name,
    required String category,
    required String breed,
    required double price,
    required String imageUrl,
  }) async {
    try {
      final favoritesRef = firestore.collection('favorites').doc(userId);
      
      // Get current favorites
      final doc = await favoritesRef.get();
      final currentItems = doc.exists 
          ? (doc.data()?['items'] as List<dynamic>?) ?? []
          : [];
      
      // Check if item already exists
      final existingIndex = currentItems.indexWhere(
        (item) => (item as Map<String, dynamic>)['productId'] == productId
      );
      
      final newFavoriteItem = {
        'productId': productId,
        'name': name,
        'category': category,
        'breed': breed,
        'price': price,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(), // ADD TIMESTAMP
      };
      
      if (existingIndex >= 0) {
        // Update existing item with new timestamp
        currentItems[existingIndex] = newFavoriteItem;
        print('📝 Updated existing favorite with new timestamp: $name');
      } else {
        // Add new item
        currentItems.add(newFavoriteItem);
        print('✅ Added new favorite with timestamp: $name');
      }
      
      // Save back to Firestore
      await favoritesRef.set({
        'items': currentItems,
        'updatedAt': Timestamp.now(),
      });
      
      print('💖 Favorites updated successfully with createdAt timestamp');
    } catch (e) {
      print('❌ Error adding to favorites: $e');
      rethrow;
    }
  }
  
  /// Migrate existing favorites to add createdAt timestamp
  Future<void> migrateFavoritesToIncludeTimestamp() async {
    try {
      print('🔄 Starting favorites migration to add createdAt timestamps...');
      
      final favoritesSnapshot = await firestore.collection('favorites').get();
      int migratedUsers = 0;
      int migratedItems = 0;
      
      for (final doc in favoritesSnapshot.docs) {
        final data = doc.data();
        final items = data['items'] as List<dynamic>? ?? [];
        
        bool needsUpdate = false;
        final updatedItems = <Map<String, dynamic>>[];
        
        for (final item in items) {
          final itemMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
          
          // Add createdAt if not exists
          if (!itemMap.containsKey('createdAt')) {
            // Default to 30 days ago for existing favorites
            itemMap['createdAt'] = Timestamp.fromDate(
              DateTime.now().subtract(Duration(days: 30))
            );
            needsUpdate = true;
            migratedItems++;
            print('📅 Added createdAt to: ${itemMap['name']}');
          }
          
          updatedItems.add(itemMap);
        }
        
        if (needsUpdate) {
          await doc.reference.update({
            'items': updatedItems,
            'migratedAt': Timestamp.now(),
          });
          migratedUsers++;
          print('✅ Migrated favorites for user: ${doc.id}');
        }
      }
      
      print('🎉 Migration completed!');
      print('📊 Statistics:');
      print('  - Users migrated: $migratedUsers');
      print('  - Items migrated: $migratedItems');
      
    } catch (e) {
      print('❌ Error during migration: $e');
      rethrow;
    }
  }
}