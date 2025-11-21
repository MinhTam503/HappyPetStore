import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script để admin tạo nhóm cộng đồng chính
/// Chạy: dart run bin/create_community_group.dart
Future<void> main() async {
  print('🚀 Bắt đầu tạo nhóm cộng đồng...');

  try {
    // Khởi tạo Firebase
    await Firebase.initializeApp();
    print('✅ Đã kết nối Firebase');

    final firestore = FirebaseFirestore.instance;

    // ID admin - thay đổi theo admin thực tế của bạn
    const adminId = 'ADMIN_USER_ID'; // TODO: Thay bằng ID admin thực tế

    // Kiểm tra xem đã có nhóm cộng đồng chưa
    final existingGroups = await firestore
        .collection('groupConversations')
        .where('name', isEqualTo: 'Cộng đồng Pet Lovers')
        .get();

    if (existingGroups.docs.isNotEmpty) {
      print('⚠️  Nhóm cộng đồng đã tồn tại!');
      print('   Group ID: ${existingGroups.docs.first.id}');
      return;
    }

    // Tạo nhóm cộng đồng mới
    final groupData = {
      'name': 'Cộng đồng Pet Lovers',
      'avatarUrl': 'https://firebasestorage.googleapis.com/v0/b/your-project/o/group_avatar.jpg?alt=media', // TODO: Upload avatar và thay URL
      'participants': [adminId],
      'createdBy': adminId,
      'isPublic': true,
      'lastMessage': 'Chào mừng đến với cộng đồng!',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'participantsInfo': {
        adminId: {
          'name': 'Admin',
          'avatar': '', // TODO: Thay bằng avatar admin
        },
      },
      'admins': [adminId],
      'unreadCount': {},
    };

    final docRef = await firestore.collection('groupConversations').add(groupData);
    
    // Thêm tin nhắn chào mừng
    await docRef.collection('messages').add({
      'senderId': adminId,
      'text': 'Chào mừng tất cả mọi người đến với nhóm cộng đồng Pet Lovers! 🐾\n\nĐây là nơi để chúng ta chia sẻ, trao đổi về thú cưng yêu quý của mình.',
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': {adminId: true},
    });

    print('✅ Đã tạo nhóm cộng đồng thành công!');
    print('   Group ID: ${docRef.id}');
    print('   Tên nhóm: Cộng đồng Pet Lovers');
    print('   Loại: Public');
    print('');
    print('📝 Lưu ý:');
    print('   - Cần thay ADMIN_USER_ID bằng ID admin thực tế');
    print('   - Cần upload avatar cho nhóm và cập nhật avatarUrl');
    print('   - Người dùng có thể tham gia nhóm từ tab Cộng đồng');
  } catch (e) {
    print('❌ Lỗi: $e');
  }
}
