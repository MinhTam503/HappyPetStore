import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/recommendation_entities.dart';

class SampleInteractionCreator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createSampleInteractions(String userId) async {
    try {
      print('🔧 Creating sample interactions for user: $userId');
      
      // Get some pets to create interactions with
      final petsSnapshot = await _firestore
          .collection('Pets')
          .limit(5)
          .get();
      
      if (petsSnapshot.docs.isEmpty) {
        print('❌ No pets found to create sample interactions');
        return;
      }

      final sampleInteractions = [
        UserInteraction(
          userId: userId,
          petId: petsSnapshot.docs[0].id,
          type: InteractionType.view,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          weight: 1.0,
        ),
        UserInteraction(
          userId: userId,
          petId: petsSnapshot.docs[0].id,
          type: InteractionType.favorite,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          weight: 3.0,
        ),
        UserInteraction(
          userId: userId,
          petId: petsSnapshot.docs.length > 1 ? petsSnapshot.docs[1].id : petsSnapshot.docs[0].id,
          type: InteractionType.view,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          weight: 1.0,
        ),
        UserInteraction(
          userId: userId,
          petId: petsSnapshot.docs.length > 2 ? petsSnapshot.docs[2].id : petsSnapshot.docs[0].id,
          type: InteractionType.cart,
          timestamp: DateTime.now().subtract(const Duration(hours: 12)),
          weight: 4.0,
        ),
        UserInteraction(
          userId: userId,
          petId: petsSnapshot.docs.length > 1 ? petsSnapshot.docs[1].id : petsSnapshot.docs[0].id,
          type: InteractionType.favorite,
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          weight: 3.0,
        ),
      ];

      final batch = _firestore.batch();
      for (final interaction in sampleInteractions) {
        final docRef = _firestore.collection('user_interactions').doc();
        batch.set(docRef, interaction.toMap());
      }
      
      await batch.commit();
      print('✅ Created ${sampleInteractions.length} sample interactions successfully');
      
      // Print created interactions for verification
      for (int i = 0; i < sampleInteractions.length; i++) {
        final interaction = sampleInteractions[i];
        print('📝 Interaction ${i + 1}: ${interaction.type} on pet ${interaction.petId} (weight: ${interaction.weight})');
      }
      
    } catch (e) {
      print('❌ Error creating sample interactions: $e');
      rethrow;
    }
  }

  static Future<void> checkUserInteractions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_interactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      print('📊 Found ${snapshot.docs.length} interactions for user $userId:');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('  - ${data['type']} on ${data['petId']} at ${data['timestamp']} (weight: ${data['weight']})');
      }
      
    } catch (e) {
      print('❌ Error checking user interactions: $e');
    }
  }
}