import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/domain/entities/group_chat_entities.dart';
import 'package:pet_shop/domain/repositories/group_chat_repository.dart';

class GroupChatRepositoryImpl implements GroupChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _groupsRef => _firestore.collection('groupConversations');

  @override
  Future<GroupConversation> createGroup({
    required String name,
    required String createdBy,
    required List<String> participants,
    required Map<String, dynamic> participantsInfo,
    String? avatarUrl,
    bool isPublic = false,
  }) async {
    try {
      final doc = _groupsRef.doc();
      final group = GroupConversation(
        id: doc.id,
        name: name,
        avatarUrl: avatarUrl,
        participants: participants,
        createdBy: createdBy,
        isPublic: isPublic,
        lastMessage: null,
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: null,
        unreadCount: {for (var id in participants) id: 0},
        createdAt: DateTime.now(),
        participantsInfo: participantsInfo,
        admins: [createdBy], // Creator is admin
      );

      await doc.set({
        'name': group.name,
        'avatarUrl': group.avatarUrl,
        'participants': group.participants,
        'createdBy': group.createdBy,
        'isPublic': group.isPublic,
        'lastMessage': group.lastMessage,
        'lastMessageTime': Timestamp.fromDate(group.lastMessageTime),
        'lastMessageSenderId': group.lastMessageSenderId,
        'unreadCount': group.unreadCount,
        'createdAt': Timestamp.fromDate(group.createdAt),
        'participantsInfo': group.participantsInfo,
        'admins': group.admins,
      });

      if (kDebugMode) print('✅ Created group: ${group.id}');
      return group;
    } catch (e) {
      if (kDebugMode) print('❌ Error creating group: $e');
      rethrow;
    }
  }

  @override
  Future<List<GroupConversation>> getUserGroups(String userId) async {
    try {
      final snapshot = await _groupsRef
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      return snapshot.docs.map((doc) => _groupFromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting user groups: $e');
      return [];
    }
  }

  @override
  Future<List<GroupConversation>> getPublicGroups({int limit = 20}) async {
    try {
      final snapshot = await _groupsRef
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => _groupFromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting public groups: $e');
      return [];
    }
  }

  @override
  Future<GroupConversation?> getGroup(String groupId) async {
    try {
      final doc = await _groupsRef.doc(groupId).get();
      if (!doc.exists) return null;
      return _groupFromFirestore(doc);
    } catch (e) {
      if (kDebugMode) print('❌ Error getting group: $e');
      return null;
    }
  }

  @override
  Future<void> joinGroup({
    required String groupId,
    required String userId,
    required Map<String, dynamic> userInfo,
  }) async {
    try {
      await _groupsRef.doc(groupId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'participantsInfo.$userId': userInfo,
        'unreadCount.$userId': 0,
      });
      if (kDebugMode) print('✅ User $userId joined group $groupId');
    } catch (e) {
      if (kDebugMode) print('❌ Error joining group: $e');
      rethrow;
    }
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _groupsRef.doc(groupId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantsInfo.$userId': FieldValue.delete(),
        'unreadCount.$userId': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([userId]),
      });
      if (kDebugMode) print('✅ User $userId left group $groupId');
    } catch (e) {
      if (kDebugMode) print('❌ Error leaving group: $e');
      rethrow;
    }
  }

  @override
  Future<void> addMembers({
    required String groupId,
    required List<String> userIds,
    required Map<String, dynamic> usersInfo,
  }) async {
    try {
      final batch = _firestore.batch();
      final groupRef = _groupsRef.doc(groupId);
      
      batch.update(groupRef, {
        'participants': FieldValue.arrayUnion(userIds),
      });
      
      for (var userId in userIds) {
        batch.update(groupRef, {
          'participantsInfo.$userId': usersInfo[userId],
          'unreadCount.$userId': 0,
        });
      }
      
      await batch.commit();
      if (kDebugMode) print('✅ Added members to group $groupId');
    } catch (e) {
      if (kDebugMode) print('❌ Error adding members: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _groupsRef.doc(groupId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantsInfo.$userId': FieldValue.delete(),
        'unreadCount.$userId': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([userId]),
      });
      if (kDebugMode) print('✅ Removed member $userId from group $groupId');
    } catch (e) {
      if (kDebugMode) print('❌ Error removing member: $e');
      rethrow;
    }
  }

  @override
  Future<GroupChatMessage> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String text,
    String? replyToId,
  }) async {
    try {
      final messagesRef = _groupsRef.doc(groupId).collection('messages');
      final messageDoc = messagesRef.doc();
      
      final message = GroupChatMessage(
        id: messageDoc.id,
        groupId: groupId,
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
        readBy: {senderId: true},
        replyToId: replyToId,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'readBy': message.readBy,
        'replyToId': message.replyToId,
        'reactions': {},
        'isSystemMessage': false,
      });

      // Update group last message
      await _updateGroupLastMessage(
        groupId: groupId,
        lastMessage: text,
        senderId: senderId,
      );

      return message;
    } catch (e) {
      if (kDebugMode) print('❌ Error sending group message: $e');
      rethrow;
    }
  }

  @override
  Future<GroupChatMessage> sendGroupImage({
    required String groupId,
    required String senderId,
    required String imageUrl,
    String? replyToId,
  }) async {
    try {
      final messagesRef = _groupsRef.doc(groupId).collection('messages');
      final messageDoc = messagesRef.doc();
      
      final message = GroupChatMessage(
        id: messageDoc.id,
        groupId: groupId,
        senderId: senderId,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
        readBy: {senderId: true},
        replyToId: replyToId,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'readBy': message.readBy,
        'replyToId': message.replyToId,
        'reactions': {},
        'isSystemMessage': false,
      });

      await _updateGroupLastMessage(
        groupId: groupId,
        lastMessage: '📷 Photo',
        senderId: senderId,
      );

      return message;
    } catch (e) {
      if (kDebugMode) print('❌ Error sending group image: $e');
      rethrow;
    }
  }

  @override
  Future<List<GroupChatMessage>> getGroupMessages(String groupId, {int limit = 50}) async {
    try {
      final snapshot = await _groupsRef
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => _messageFromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error getting group messages: $e');
      return [];
    }
  }

  @override
  Stream<List<GroupChatMessage>> streamGroupMessages(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // ascending: tin cũ ở dưới
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => _messageFromFirestore(doc)).toList());
  }

  @override
  Future<void> markGroupMessagesAsRead(String groupId, String userId) async {
    try {
      final snapshot = await _groupsRef
          .doc(groupId)
          .collection('messages')
          .where('readBy.$userId', isEqualTo: null)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'readBy.$userId': true});
      }
      await batch.commit();

      // Reset unread count
      await _groupsRef.doc(groupId).update({'unreadCount.$userId': 0});
    } catch (e) {
      if (kDebugMode) print('❌ Error marking messages as read: $e');
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      // Delete all messages
      final messages = await _groupsRef.doc(groupId).collection('messages').get();
      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete group
      await _groupsRef.doc(groupId).delete();
      if (kDebugMode) print('✅ Deleted group $groupId');
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting group: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
      
      if (updates.isNotEmpty) {
        await _groupsRef.doc(groupId).update(updates);
        if (kDebugMode) print('✅ Updated group $groupId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating group: $e');
      rethrow;
    }
  }

  // Helper methods
  Future<void> _updateGroupLastMessage({
    required String groupId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      final group = await getGroup(groupId);
      if (group == null) return;

      // Increment unread count for all participants except sender
      final unreadUpdates = <String, dynamic>{};
      for (var participantId in group.participants) {
        if (participantId != senderId) {
          final currentCount = group.unreadCount[participantId] ?? 0;
          unreadUpdates['unreadCount.$participantId'] = currentCount + 1;
        }
      }

      await _groupsRef.doc(groupId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        ...unreadUpdates,
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error updating last message: $e');
    }
  }

  GroupConversation _groupFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupConversation(
      id: doc.id,
      name: data['name'] ?? '',
      avatarUrl: data['avatarUrl'],
      participants: List<String>.from(data['participants'] ?? []),
      createdBy: data['createdBy'] ?? '',
      isPublic: data['isPublic'] ?? false,
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      participantsInfo: Map<String, dynamic>.from(data['participantsInfo'] ?? {}),
      admins: List<String>.from(data['admins'] ?? []),
    );
  }

  GroupChatMessage _messageFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupChatMessage(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy: Map<String, bool>.from(data['readBy'] ?? {}),
      replyToId: data['replyToId'],
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      isSystemMessage: data['isSystemMessage'] ?? false,
    );
  }
}
