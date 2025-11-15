import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration script to fix stats mismatch in socialPetProfiles
/// Run this once to sync stats.followers and stats.following with actual array lengths
Future<void> fixFollowStatsForAllProfiles() async {
  final firestore = FirebaseFirestore.instance;
  final profilesRef = firestore.collection('socialPetProfiles');
  
  print('🔧 Starting stats synchronization...');
  
  try {
    final snapshot = await profilesRef.get();
    int fixedCount = 0;
    int errorCount = 0;
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        
        // Get array lengths
        final followers = List<String>.from(data['followers'] ?? []);
        final following = List<String>.from(data['following'] ?? []);
        final actualFollowersCount = followers.length;
        final actualFollowingCount = following.length;
        
        // Get current stats
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        final currentFollowersCount = stats['followers'] ?? 0;
        final currentFollowingCount = stats['following'] ?? 0;
        
        // Check if sync needed
        if (currentFollowersCount != actualFollowersCount || 
            currentFollowingCount != actualFollowingCount) {
          
          print('📝 Fixing ${doc.id}:');
          print('   Followers: $currentFollowersCount → $actualFollowersCount');
          print('   Following: $currentFollowingCount → $actualFollowingCount');
          
          // Update stats to match arrays
          await doc.reference.update({
            'stats.followers': actualFollowersCount,
            'stats.following': actualFollowingCount,
          });
          
          fixedCount++;
        }
      } catch (e) {
        print('❌ Error fixing ${doc.id}: $e');
        errorCount++;
      }
    }
    
    print('\n✅ Migration complete!');
    print('   Fixed: $fixedCount profiles');
    print('   Errors: $errorCount profiles');
    print('   Total: ${snapshot.docs.length} profiles');
    
  } catch (e) {
    print('❌ Migration failed: $e');
    rethrow;
  }
}

/// Clean up duplicate follows (multiple follow documents for same user-pet pair)
Future<void> cleanUpDuplicateFollows() async {
  final firestore = FirebaseFirestore.instance;
  final followsRef = firestore.collection('socialPetFollows');
  final profilesRef = firestore.collection('socialPetProfiles');
  
  print('🔧 Cleaning up duplicate follows...');
  
  try {
    final snapshot = await followsRef.get();
    final followMap = <String, List<String>>{}; // petId -> [followerIds]
    
    // Group followers by pet
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final petId = data['followingPetId'] as String;
      final followerId = data['followerId'] as String;
      
      if (!followMap.containsKey(petId)) {
        followMap[petId] = [];
      }
      followMap[petId]!.add(followerId);
    }
    
    int fixedCount = 0;
    
    // Fix each profile
    for (final entry in followMap.entries) {
      final petId = entry.key;
      final uniqueFollowers = entry.value.toSet().toList();
      
      if (uniqueFollowers.length != entry.value.length) {
        print('📝 Fixing duplicates for $petId');
        print('   Followers: ${entry.value.length} → ${uniqueFollowers.length}');
        
        // Update profile with unique followers
        await profilesRef.doc(petId).update({
          'followers': uniqueFollowers,
          'stats.followers': uniqueFollowers.length,
        });
        
        fixedCount++;
      }
    }
    
    print('\n✅ Cleanup complete!');
    print('   Fixed: $fixedCount profiles with duplicates');
    
  } catch (e) {
    print('❌ Cleanup failed: $e');
    rethrow;
  }
}

/// Run all migrations
Future<void> runAllMigrations() async {
  print('=' * 50);
  print('🚀 Starting all migrations');
  print('=' * 50);
  
  await cleanUpDuplicateFollows();
  print('\n');
  await fixFollowStatsForAllProfiles();
  
  print('\n' + '=' * 50);
  print('✅ All migrations completed!');
  print('=' * 50);
}
