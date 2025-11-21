import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/core/services/user_manager.dart';

/// Service để quản lý nhóm cộng đồng
class CommunityGroupService {
  static const String _communityGroupId = 'main_community_group';
  static const String _groupName = 'Cộng đồng Pet Lovers';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kiểm tra và tạo nhóm cộng đồng nếu chưa có
  /// Chỉ chạy 1 lần duy nhất khi app khởi động
  Future<void> ensureCommunityGroupExists() async {
    try {
      final groupDoc = await _firestore
          .collection('groupConversations')
          .doc(_communityGroupId)
          .get();

      if (!groupDoc.exists) {
        // Lấy thông tin user hiện tại (người tạo nhóm đầu tiên)
        final currentUserId = UserManager().currentUserId;
        if (currentUserId == null) return;

        // Lấy thông tin profile của user
        final userDoc = await _firestore
            .collection('socialPetProfiles')
            .doc(currentUserId)
            .get();

        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        final userName = userData['displayName'] ?? 'User';
        final userAvatar = userData['avatar'] ?? '';

        // Tạo nhóm cộng đồng
        await _firestore
            .collection('groupConversations')
            .doc(_communityGroupId)
            .set({
          'name': _groupName,
          'avatarUrl': 'https://firebasestorage.googleapis.com/v0/b/happypetstore-a1f46.appspot.com/o/group_avatars%2Fcommunity_default.png?alt=media',
          'participants': [currentUserId],
          'createdBy': currentUserId,
          'isPublic': true,
          'lastMessage': 'Chào mừng đến với cộng đồng Pet Lovers! 🐾',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'participantsInfo': {
            currentUserId: {
              'name': userName,
              'avatar': userAvatar,
            },
          },
          'admins': [currentUserId],
          'unreadCount': {},
        });

        // Thêm tin nhắn chào mừng
        await _firestore
            .collection('groupConversations')
            .doc(_communityGroupId)
            .collection('messages')
            .add({
          'senderId': currentUserId,
          'text': 'Chào mừng tất cả mọi người đến với cộng đồng Pet Lovers! 🐾\n\nĐây là nơi để chúng ta chia sẻ, trao đổi về thú cưng yêu quý của mình.',
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': {currentUserId: true},
        });

        print('✅ Đã tạo nhóm cộng đồng thành công');
      }
    } catch (e) {
      print('❌ Lỗi khi tạo nhóm cộng đồng: $e');
    }
  }

  /// Kiểm tra user đã join nhóm chưa
  Future<bool> isUserInGroup(String groupId, String userId) async {
    try {
      final groupDoc = await _firestore
          .collection('groupConversations')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return false;

      final participants = List<String>.from(groupDoc.data()?['participants'] ?? []);
      return participants.contains(userId);
    } catch (e) {
      print('❌ Lỗi kiểm tra membership: $e');
      return false;
    }
  }

  /// Join nhóm
  Future<bool> joinGroup(String groupId, String userId) async {
    try {
      // Lấy thông tin user
      final userDoc = await _firestore
          .collection('socialPetProfiles')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userName = userData['displayName'] ?? 'User';
      final userAvatar = userData['avatar'] ?? '';

      // Cập nhật group
      await _firestore
          .collection('groupConversations')
          .doc(groupId)
          .update({
        'participants': FieldValue.arrayUnion([userId]),
        'participantsInfo.$userId': {
          'name': userName,
          'avatar': userAvatar,
        },
        'unreadCount.$userId': 0,
      });

      // Thêm message thông báo join
      await _firestore
          .collection('groupConversations')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': userId,
        'text': '$userName đã tham gia nhóm',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': {userId: true},
        'isSystemMessage': true, // Đánh dấu là tin nhắn hệ thống
      });

      return true;
    } catch (e) {
      print('❌ Lỗi khi join nhóm: $e');
      return false;
    }
  }
}
