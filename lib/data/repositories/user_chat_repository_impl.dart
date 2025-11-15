import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/domain/entities/chat_entities.dart';
import 'package:pet_shop/domain/repositories/user_chat_repository.dart';

class UserChatRepositoryImpl implements UserChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _conversationsRef =>
      _firestore.collection('chatConversations');

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
    required Map<String, dynamic> participantsInfo,
  }) async {
    try {
      // Create a consistent conversation ID
      final participants = [currentUserId, otherUserId]..sort();
      final conversationId = participants.join('_');

      final doc = await _conversationsRef.doc(conversationId).get();

      if (doc.exists) {
        return _conversationFromFirestore(doc);
      }

      // Create new conversation
      final conversation = ChatConversation(
        id: conversationId,
        participants: participants,
        lastMessage: null,
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: null,
        unreadCount: {currentUserId: 0, otherUserId: 0},
        createdAt: DateTime.now(),
        participantsInfo: participantsInfo,
      );

      await _conversationsRef.doc(conversationId).set({
        'participants': conversation.participants,
        'lastMessage': conversation.lastMessage,
        'lastMessageTime': Timestamp.fromDate(conversation.lastMessageTime),
        'lastMessageSenderId': conversation.lastMessageSenderId,
        'unreadCount': conversation.unreadCount,
        'createdAt': Timestamp.fromDate(conversation.createdAt),
        'participantsInfo': conversation.participantsInfo,
      });

      if (kDebugMode) {
        print('✅ Created conversation: $conversationId');
      }

      return conversation;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating conversation: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<ChatConversation>> getConversations(String userId) async {
    try {
      final snapshot = await _conversationsRef
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => _conversationFromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting conversations: $e');
      }
      return [];
    }
  }

  @override
  Future<ChatConversation?> getConversation(String conversationId) async {
    try {
      final doc = await _conversationsRef.doc(conversationId).get();
      if (!doc.exists) return null;
      return _conversationFromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting conversation: $e');
      }
      return null;
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? replyToId,
  }) async {
    try {
      final messagesRef = _conversationsRef
          .doc(conversationId)
          .collection('messages');

      final messageDoc = messagesRef.doc();
      final message = ChatMessage(
        id: messageDoc.id,
        conversationId: conversationId,
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
        isRead: false,
        replyToId: replyToId,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'isRead': message.isRead,
        'replyToId': message.replyToId,
      });

      // Update conversation
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: text,
        senderId: senderId,
      );

      if (kDebugMode) {
        print('✅ Sent message in conversation: $conversationId');
      }

      return message;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending message: $e');
      }
      rethrow;
    }
  }

  @override
  Future<ChatMessage> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String imageUrl,
    String? replyToId,
  }) async {
    try {
      final messagesRef = _conversationsRef
          .doc(conversationId)
          .collection('messages');

      final messageDoc = messagesRef.doc();
      final message = ChatMessage(
        id: messageDoc.id,
        conversationId: conversationId,
        senderId: senderId,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
        isRead: false,
        replyToId: replyToId,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'isRead': message.isRead,
        'replyToId': message.replyToId,
      });

      // Update conversation
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '📷 Photo',
        senderId: senderId,
      );

      if (kDebugMode) {
        print('✅ Sent image message in conversation: $conversationId');
      }

      return message;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending image message: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId,
      {int limit = 50}) async {
    try {
      final snapshot = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => _messageFromFirestore(doc, conversationId))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting messages: $e');
      }
      return [];
    }
  }

  @override
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _messageFromFirestore(doc, conversationId))
            .toList());
  }

  @override
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final batch = _firestore.batch();

      final unreadMessages = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Reset unread count for this user
      batch.update(_conversationsRef.doc(conversationId), {
        'unreadCount.$userId': 0,
      });

      await batch.commit();

      if (kDebugMode) {
        print('✅ Marked messages as read in conversation: $conversationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking messages as read: $e');
      }
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages
      final messagesSnapshot = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete conversation
      batch.delete(_conversationsRef.doc(conversationId));

      await batch.commit();

      if (kDebugMode) {
        print('✅ Deleted conversation: $conversationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting conversation: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();

      if (kDebugMode) {
        print('✅ Deleted message: $messageId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting message: $e');
      }
      rethrow;
    }
  }

  // Helper methods

  Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String senderId,
  }) async {
    final conversationDoc = await _conversationsRef.doc(conversationId).get();
    final data = conversationDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants']);
    final otherUserId = participants.firstWhere((id) => id != senderId);

    await _conversationsRef.doc(conversationId).update({
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  ChatConversation _conversationFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantsInfo: Map<String, dynamic>.from(data['participantsInfo'] ?? {}),
    );
  }

  ChatMessage _messageFromFirestore(
      DocumentSnapshot doc, String conversationId) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      replyToId: data['replyToId'],
    );
  }
}
