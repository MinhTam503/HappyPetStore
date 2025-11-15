# 💬 Chat Implementation - Complete Guide

## ✅ HOÀN THÀNH - Hệ thống chat 1-1 đầy đủ

### Tổng quan
Đã implement đầy đủ chat system với:
- ✅ Chat List (danh sách conversations)
- ✅ Chat Room (phòng chat 1-1)
- ✅ Text messages
- ✅ Image messages với Firebase Storage
- ✅ Real-time updates
- ✅ Unread count
- ✅ Mark as read
- ✅ Pull-to-refresh
- ✅ Empty states
- ✅ Full localization

---

## 🎯 Cách sử dụng

### 1. Xem danh sách tin nhắn
**Từ Social Home Page:**
1. Tap icon Messages (chat_bubble_outline) trên AppBar
2. Hiển thị ChatListPage với:
   - Avatar người chat
   - Tên người chat
   - Last message preview
   - Timestamp
   - Unread badge (nếu có tin nhắn chưa đọc)

**Navigation:**
```dart
Navigator.pushNamed(context, '/social/chat');
```

---

### 2. Bắt đầu chat từ Profile
**Từ trang profile người khác:**
1. Tap button "Nhắn tin" (Message)
2. System tự động:
   - Tạo conversation nếu chưa có
   - Load conversation nếu đã có
   - Navigate đến ChatRoomPage

**Button location:**
- Profile của người khác → dưới avatar, bên cạnh "Follow"

---

### 3. Gửi tin nhắn trong Chat Room
**Text message:**
1. Nhập text vào TextField
2. Tap Send button hoặc Enter

**Image message:**
1. Tap Image icon
2. Chọn ảnh từ gallery
3. System tự upload lên Firebase Storage
4. Gửi image URL vào message

**Features:**
- Auto-scroll to bottom khi gửi
- Real-time updates từ Firestore
- Messages tự động mark as read khi vào room
- Sender messages bên phải (primary color)
- Received messages bên trái (grey)

---

## 📁 Code Structure

### BLoC Layer
```
lib/presentation/bloc/chat/
├── chat_event.dart          (7 events)
├── chat_state.dart          (4 states)
└── chat_bloc.dart           (Event handlers with real-time streaming)
```

**Events:**
1. `LoadConversations(userId)` - Load all conversations
2. `CreateConversation(...)` - Create/get conversation
3. `LoadMessages(conversationId)` - Stream messages real-time
4. `SendMessage(...)` - Send text message
5. `SendImageMessage(...)` - Send image message
6. `MarkMessagesAsRead(...)` - Update read status
7. `DeleteConversation(conversationId)` - Delete conversation

**States:**
- `ChatInitial` - Trạng thái ban đầu
- `ChatLoading` - Đang load data
- `ChatLoaded` - Data đã load (conversations, messages, activeConversationId)
- `ChatError(message)` - Có lỗi xảy ra

---

### UI Pages
```
lib/presentation/pages/mobile/social/
├── chat_list_page.dart      (~200 lines)
└── chat_room_page.dart      (~400 lines)
```

**ChatListPage:**
- ListView của conversations
- Pull-to-refresh support
- Empty state khi chưa có chat
- Unread badge với số tin nhắn
- Timestamp formatting (HH:mm, Hôm qua, dd/MM/yy)

**ChatRoomPage:**
- AppBar với avatar + tên user
- StreamBuilder cho real-time messages
- Message bubbles (left/right alignment)
- Input bar với image picker + text field
- Auto-scroll khi gửi tin nhắn
- Loading state khi upload ảnh

---

### Repository Layer
```
lib/domain/repositories/
└── user_chat_repository.dart        (Interface)

lib/data/repositories/
└── user_chat_repository_impl.dart   (~370 lines)
```

**Methods:**
```dart
// Create or get existing conversation
Future<ChatConversation> getOrCreateConversation({
  required String currentUserId,
  required String otherUserId,
  required Map<String, dynamic> participantsInfo,
});

// Send messages
Future<ChatMessage> sendMessage({
  required String conversationId,
  required String senderId,
  required String text,
});

Future<ChatMessage> sendImageMessage({
  required String conversationId,
  required String senderId,
  required String imageUrl,
});

// Real-time streaming
Stream<List<ChatMessage>> streamMessages(String conversationId);

// Mark as read (updates unreadCount)
Future<void> markMessagesAsRead(String conversationId, String userId);

// Get conversations list
Future<List<ChatConversation>> getConversations(String userId);
```

---

## 🔥 Firestore Structure

### Collection: `chatConversations`
```firestore
chatConversations/{conversationId}
  ├── participants: [userId1, userId2]
  ├── lastMessage: "Hello!"
  ├── lastMessageTime: Timestamp(2024-01-15 10:30:00)
  ├── lastMessageSenderId: "userId1"
  ├── unreadCount: {
  │     userId1: 0,
  │     userId2: 3
  │   }
  ├── createdAt: Timestamp
  └── participantsInfo: {
        userId1: {
          name: "John Doe",
          avatarUrl: "https://..."
        },
        userId2: {
          name: "Jane Smith",
          avatarUrl: "https://..."
        }
      }
```

**conversationId format:** `{userId1}_{userId2}` (sorted alphabetically)
- Ví dụ: `abc123_xyz789`
- Đảm bảo 2 users luôn có cùng conversationId

---

### Subcollection: `messages`
```firestore
chatConversations/{conversationId}/messages/{messageId}
  ├── senderId: "userId1"
  ├── text: "Hello, how are you?"
  ├── imageUrl: null  // or "https://..." for image messages
  ├── timestamp: Timestamp(2024-01-15 10:30:15)
  └── isRead: false
```

**Queries:**
```dart
// Stream messages real-time (ordered by timestamp DESC)
_conversationsRef
  .doc(conversationId)
  .collection('messages')
  .orderBy('timestamp', descending: true)
  .limit(50)
  .snapshots()
```

---

## 🎨 UI Components

### 1. Chat List Item
```
┌─────────────────────────────────────┐
│ ○ Jane Smith           [2]  10:30  │
│   Hey, how are you?                 │
└─────────────────────────────────────┘
```
- CircleAvatar (28px radius)
- Name (bold if unread)
- Last message (1 line, ellipsis)
- Unread badge (primary color với số)
- Timestamp

### 2. Message Bubble
**Received (left, grey):**
```
┌──────────────────┐
│ Hello!           │
│                  │
└──────────────────┘
  10:30
```

**Sent (right, primary color):**
```
           ┌──────────────────┐
           │ How are you?     │
           │                  │
           └──────────────────┘
                         10:31
```

**With Image:**
```
┌──────────────────┐
│ [IMAGE]          │
│ Check this out!  │
└──────────────────┘
  10:32
```

### 3. Input Bar
```
┌─────────────────────────────────────┐
│ [📷]  [Type a message...]      [📤] │
└─────────────────────────────────────┘
```
- Image picker button (left)
- TextField (center, grey background, rounded)
- Send button (right, primary color circle)

---

## 🌐 Localization

**Added keys in app_vi.arb & app_en.arb:**

| Key | Vietnamese | English |
|-----|-----------|---------|
| messages | Tin nhắn | Messages |
| noMessagesYet | Chưa có tin nhắn | No messages yet |
| noConversationsYet | Chưa có cuộc trò chuyện nào | No conversations yet |
| sendFirstMessage | Gửi tin nhắn đầu tiên! | Send the first message! |
| typeMessage | Nhập tin nhắn... | Type a message... |
| send | Gửi | Send |
| retry | Thử lại | Retry |
| unknown | Chưa rõ | Unknown |

---

## 🔧 Integration in main.dart

### Routes
```dart
// Chat routes
if (settings.name == '/social/chat') {
  return MaterialPageRoute(
    builder: (_) => const ChatListPage(),
  );
}

if (settings.name == '/social/chat/room') {
  final args = settings.arguments as Map<String, dynamic>;
  return MaterialPageRoute(
    builder: (_) => ChatRoomPage(
      conversationId: args['conversationId'],
      otherUserId: args['otherUserId'],
      otherUserName: args['otherUserName'],
      otherUserAvatar: args['otherUserAvatar'],
    ),
  );
}
```

### BLoC Provider
```dart
BlocProvider(
  create: (_) => ChatBloc(
    chatRepository: UserChatRepositoryImpl(),
  ),
),
```

### Imports
```dart
import 'package:pet_shop/presentation/bloc/chat/chat_bloc.dart';
import 'package:pet_shop/data/repositories/user_chat_repository_impl.dart';
import 'package:pet_shop/presentation/pages/mobile/social/chat_list_page.dart';
import 'package:pet_shop/presentation/pages/mobile/social/chat_room_page.dart';
```

---

## 📝 Usage Examples

### Example 1: Load conversations
```dart
// In ChatListPage initState
@override
void initState() {
  super.initState();
  final userId = UserManager().currentUserId ?? '';
  context.read<ChatBloc>().add(LoadConversations(userId));
}
```

### Example 2: Start chat from profile
```dart
// In SocialProfilePage - Message button
OutlinedButton.icon(
  onPressed: () {
    final participants = [currentUserId, otherUserId]..sort();
    final conversationId = participants.join('_');
    
    // Create conversation
    context.read<ChatBloc>().add(CreateConversation(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      otherUserName: otherUserDisplayName,
      otherUserAvatar: otherUserAvatarUrl,
    ));
    
    // Navigate to chat room
    Navigator.pushNamed(context, '/social/chat/room', arguments: {
      'conversationId': conversationId,
      'otherUserId': otherUserId,
      'otherUserName': otherUserDisplayName,
      'otherUserAvatar': otherUserAvatarUrl,
    });
  },
  icon: Icon(Icons.chat_bubble_outline),
  label: Text('Nhắn tin'),
)
```

### Example 3: Send message in Chat Room
```dart
// Text message
void _sendMessage() {
  final text = _messageController.text.trim();
  if (text.isEmpty) return;
  
  context.read<ChatBloc>().add(SendMessage(
    conversationId: widget.conversationId,
    senderId: _currentUserId,
    text: text,
  ));
  
  _messageController.clear();
}

// Image message
Future<void> _pickAndSendImage() async {
  final image = await _imagePicker.pickImage(source: ImageSource.gallery);
  if (image == null) return;
  
  // Upload to Firebase Storage
  final storageRef = FirebaseStorage.instance
      .ref()
      .child('chat_images')
      .child('${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
  
  await storageRef.putFile(File(image.path));
  final imageUrl = await storageRef.getDownloadURL();
  
  // Send image message
  context.read<ChatBloc>().add(SendImageMessage(
    conversationId: widget.conversationId,
    senderId: _currentUserId,
    imageUrl: imageUrl,
  ));
}
```

### Example 4: Mark messages as read
```dart
// In ChatRoomPage initState
void _markAsRead() {
  context.read<ChatBloc>().add(MarkMessagesAsRead(
    conversationId: widget.conversationId,
    userId: _currentUserId,
  ));
}
```

---

## 🚀 Testing Checklist

- [ ] View chat list (empty state)
- [ ] Start chat from profile → creates conversation
- [ ] Send text message → appears in chat room
- [ ] Send image message → uploads and displays
- [ ] Real-time updates → new messages appear automatically
- [ ] Unread count → increases when receiving messages
- [ ] Mark as read → unread count resets to 0
- [ ] Back to chat list → shows updated last message
- [ ] Timestamp formatting → HH:mm, Hôm qua, dd/MM/yy
- [ ] Pull-to-refresh → reloads conversations
- [ ] Navigation icons work from Social Home

---

## 🎉 Completed!

**All features implemented:**
- ✅ Chat BLoC with 7 events
- ✅ Chat List Page with unread badges
- ✅ Chat Room Page with text + image support
- ✅ Firebase Storage integration
- ✅ Real-time messaging with Firestore streams
- ✅ Localization (VI + EN)
- ✅ Navigation and routing
- ✅ Message button on profiles
- ✅ Messages icon in Social Home

**Next steps:**
1. Run app and test full chat flow
2. Test với 2 users khác nhau
3. Verify real-time updates
4. Check unread count behavior
5. Test image upload và display
