import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/domain/entities/chat_entities.dart';
import 'package:pet_shop/domain/repositories/customer_chat_repository.dart';

class CustomerChatRepositoryImpl implements CustomerChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String shopId = 'shop_admin';

  CollectionReference get _conversationsRef =>
      _firestore.collection('customerConversations');

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required Map<String, dynamic> participantsInfo,
  }) async {
    try {
      final conversationId = customerId;
      final doc = await _conversationsRef.doc(conversationId).get();

      if (doc.exists) {
        return _conversationFromFirestore(doc);
      }

      final conversation = ChatConversation(
        id: conversationId,
        participants: [customerId, shopId],
        lastMessage: null,
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: null,
        unreadCount: {customerId: 0, shopId: 0},
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

      if (kDebugMode) print('✅ Created customer conversation: $conversationId');
      return conversation;
    } catch (e) {
      if (kDebugMode) print('❌ Error creating customer conversation: $e');
      rethrow;
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      final messagesRef = _conversationsRef.doc(conversationId).collection('messages');
      final messageDoc = messagesRef.doc();
      
      final message = ChatMessage(
        id: messageDoc.id,
        conversationId: conversationId,
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'isRead': message.isRead,
        'reactions': {},
      });

      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: text,
        senderId: senderId,
      );

      if (kDebugMode) print('✅ Sent customer message');
      return message;
    } catch (e) {
      if (kDebugMode) print('❌ Error sending customer message: $e');
      rethrow;
    }
  }

  @override
  Future<ChatMessage> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String imageUrl,
  }) async {
    try {
      final messagesRef = _conversationsRef.doc(conversationId).collection('messages');
      final messageDoc = messagesRef.doc();
      
      final message = ChatMessage(
        id: messageDoc.id,
        conversationId: conversationId,
        senderId: senderId,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await messageDoc.set({
        'senderId': message.senderId,
        'text': message.text,
        'imageUrl': message.imageUrl,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'isRead': message.isRead,
        'reactions': {},
      });

      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '📷 Photo',
        senderId: senderId,
      );

      if (kDebugMode) print('✅ Sent customer image');
      return message;
    } catch (e) {
      if (kDebugMode) print('❌ Error sending customer image: $e');
      rethrow;
    }
  }

  @override
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _messageFromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final messagesSnapshot = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      batch.update(_conversationsRef.doc(conversationId), {
        'unreadCount.$userId': 0,
      });

      await batch.commit();
      if (kDebugMode) print('✅ Marked messages as read');
    } catch (e) {
      if (kDebugMode) print('❌ Error marking messages as read: $e');
    }
  }

  Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      final conversationDoc = await _conversationsRef.doc(conversationId).get();
      if (!conversationDoc.exists) return;

      final data = conversationDoc.data() as Map<String, dynamic>;
      final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
      
      final otherUserId = senderId == shopId ? conversationId : shopId;
      unreadCount[otherUserId] = (unreadCount[otherUserId] ?? 0) + 1;

      await _conversationsRef.doc(conversationId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': unreadCount,
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error updating conversation: $e');
    }
  }

  ChatConversation _conversationFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantsInfo: Map<String, dynamic>.from(data['participantsInfo'] ?? {}),
    );
  }

  ChatMessage _messageFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'],
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
    );
  }
}
