# Social Profile & Chat Implementation Guide

## ✅ Completed Features

### 1. Auto-Sync User Profile
**Khi lần đầu vào Social Network**, hệ thống tự động:
- Kiểm tra xem user đã có `socialPetProfiles` document chưa
- Nếu chưa → tạo mới bằng cách copy từ `Users` collection:
  - displayName, avatar, email, phone → vào socialPetProfiles
  - Khởi tạo followers=[], following=[], stats=0

**Code location:**
- `/lib/domain/repositories/social_repository.dart` - Interface
- `/lib/data/repositories/social_repository_impl.dart` - Method `ensureUserProfile()`
- `/lib/presentation/pages/mobile/social/social_home_page.dart` - Trigger trong `_loadData()`

**Usage:**
```dart
// Trong initState hoặc onResume
context.read<SocialBloc>().add(EnsureUserProfile(currentUserId));
```

---

### 2. View User Profile Page
**Features:**
- Avatar, displayName, bio, website
- Stats: Posts / Followers / Following counts
- TabBar: Posts grid | Followers list | Following list
- **Own profile**: "Edit Profile" button
- **Others**: "Follow" + "Message" buttons

**Code location:**
- `/lib/presentation/pages/mobile/social/social_profile_page.dart`

**Navigation:**
```dart
Navigator.pushNamed(
  context,
  '/social/profile',
  arguments: userId, // String userId
);
```

**BLoC Events:**
```dart
// Load profile data
context.read<SocialBloc>().add(LoadUserProfile(userId));
context.read<SocialBloc>().add(LoadUserPosts(userId));

// Follow/Unfollow
context.read<SocialBloc>().add(FollowPet(userId));
context.read<SocialBloc>().add(UnfollowPet(userId));
```

---

### 3. Edit Profile Page
**Features:**
- Upload avatar (Firebase Storage)
- Edit: displayName, bio, website, email, phone
- Auto-save to Firestore

**Code location:**
- `/lib/presentation/pages/mobile/social/edit_social_profile_page.dart`

**Navigation:**
```dart
Navigator.pushNamed(
  context,
  '/social/edit-profile',
  arguments: currentUserProfile, // SocialPetProfile object
);
```

**BLoC Event:**
```dart
context.read<SocialBloc>().add(
  UpdateUserProfile(userId, {
    'displayName': 'New Name',
    'bio': 'New bio',
    'avatarUrl': 'https://...',
    'website': 'https://...',
  }),
);
```

---

### 4. Followers/Following List
**Features:**
- ListView of users
- Follow/Unfollow buttons
- Tap to navigate to user profile

**Code location:**
- `/lib/presentation/pages/mobile/social/followers_list_page.dart`

**Navigation:**
```dart
// Followers mode
Navigator.pushNamed(
  context,
  '/social/followers',
  arguments: {'userId': userId, 'isFollowersMode': true},
);

// Following mode
Navigator.pushNamed(
  context,
  '/social/followers',
  arguments: {'userId': userId, 'isFollowersMode': false},
);
```

---

### 5. Chat System (Backend Ready)
**Entities:**
- `ChatConversation`: id, participants, lastMessage, unreadCount, participantsInfo
- `ChatMessage`: id, senderId, text, imageUrl, timestamp, isRead

**Repository:**
- `UserChatRepository` - Interface
- `UserChatRepositoryImpl` - Firestore implementation

**Key Methods:**
```dart
// Get or create 1-1 conversation
final conversation = await repository.getOrCreateConversation(
  currentUserId: 'user1',
  otherUserId: 'user2',
  participantsInfo: {
    'user1': {'name': 'Alice', 'avatar': 'https://...'},
    'user2': {'name': 'Bob', 'avatar': 'https://...'},
  },
);

// Send message
await repository.sendMessage(
  conversationId: conversation.id,
  senderId: currentUserId,
  text: 'Hello!',
);

// Stream messages (real-time)
repository.streamMessages(conversationId).listen((messages) {
  // Update UI with new messages
});

// Mark as read
await repository.markMessagesAsRead(conversationId, currentUserId);
```

**Code location:**
- `/lib/domain/entities/chat_entities.dart` - Entities
- `/lib/domain/repositories/user_chat_repository.dart` - Interface
- `/lib/data/repositories/user_chat_repository_impl.dart` - Implementation

---

## 🔧 TODO: Remaining Tasks

### Task 9: Create Chat BLoC
**File:** `/lib/presentation/bloc/chat/chat_bloc.dart`

**Events needed:**
```dart
class LoadConversations extends ChatEvent {
  final String userId;
}

class CreateConversation extends ChatEvent {
  final String currentUserId;
  final String otherUserId;
  final Map<String, dynamic> participantsInfo;
}

class LoadMessages extends ChatEvent {
  final String conversationId;
}

class SendMessage extends ChatEvent {
  final String conversationId;
  final String text;
}

class SendImageMessage extends ChatEvent {
  final String conversationId;
  final String imageUrl;
}

class MarkAsRead extends ChatEvent {
  final String conversationId;
  final String userId;
}
```

**States needed:**
```dart
class ChatLoaded extends ChatState {
  final List<ChatConversation> conversations;
  final Map<String, List<ChatMessage>> messagesByConversation;
  final ChatConversation? activeConversation;
}
```

---

### Task 10: Chat List Page
**File:** `/lib/presentation/pages/mobile/social/chat_list_page.dart`

**UI Components:**
- AppBar with "Messages" title
- ListView of conversations:
  - Avatar (circular)
  - User name
  - Last message preview (truncated)
  - Timestamp (relative: "2m ago", "Yesterday")
  - Unread badge (count)
- Empty state: "No conversations yet"
- Pull-to-refresh

**Navigation:**
```dart
Navigator.pushNamed(
  context,
  '/social/chat',
);
```

---

### Task 11: Chat Room Page
**File:** `/lib/presentation/pages/mobile/social/chat_room_page.dart`

**UI Components:**
- AppBar:
  - Back button
  - User avatar + name
  - Online/offline indicator (optional)
- StreamBuilder for messages:
  - ListView reversed (new at bottom)
  - Message bubbles:
    - Left: received (grey background)
    - Right: sent (primary color background)
  - Timestamp under each bubble
  - Read receipts (double checkmark)
- Input bar:
  - TextField with emoji support
  - Image picker button
  - Send button (icon)

**Navigation:**
```dart
Navigator.pushNamed(
  context,
  '/social/chat/room',
  arguments: {
    'conversationId': 'user1_user2',
    'otherUserId': 'user2',
    'otherUserName': 'Bob',
    'otherUserAvatar': 'https://...',
  },
);
```

---

### Task 12: Add Routing
**File:** `/lib/core/routing/app_routes.dart` (or similar)

Add these routes:
```dart
'/social/profile': (context) {
  final userId = ModalRoute.of(context)!.settings.arguments as String;
  return SocialProfilePage(userId: userId);
},

'/social/edit-profile': (context) {
  final profile = ModalRoute.of(context)!.settings.arguments as SocialPetProfile;
  return EditSocialProfilePage(profile: profile);
},

'/social/followers': (context) {
  final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  return FollowersListPage(
    userId: args['userId'],
    isFollowersMode: args['isFollowersMode'],
  );
},

'/social/chat': (context) {
  return ChatListPage();
},

'/social/chat/room': (context) {
  final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  return ChatRoomPage(
    conversationId: args['conversationId'],
    otherUserId: args['otherUserId'],
    otherUserName: args['otherUserName'],
    otherUserAvatar: args['otherUserAvatar'],
  );
},
```

---

## 📝 Firestore Structure

### Collection: `socialPetProfiles`
```
{
  id: "userId123",
  ownerId: "userId123",
  petName: "Alice",
  displayName: "Alice Nguyen",
  avatarUrl: "https://...",
  bio: "Pet lover 🐶",
  email: "alice@example.com",
  phone: "0123456789",
  website: "https://alice.com",
  followers: ["user1", "user2"],
  following: ["user3", "user4"],
  stats: {
    posts: 10,
    followers: 2,
    totalLikes: 50,
    totalComments: 20
  },
  createdAt: Timestamp,
  isPublic: true
}
```

### Collection: `chatConversations`
```
{
  id: "user1_user2",
  participants: ["user1", "user2"],
  lastMessage: "Hello there!",
  lastMessageTime: Timestamp,
  lastMessageSenderId: "user1",
  unreadCount: {
    "user1": 0,
    "user2": 3
  },
  createdAt: Timestamp,
  participantsInfo: {
    "user1": {
      "name": "Alice",
      "avatar": "https://..."
    },
    "user2": {
      "name": "Bob",
      "avatar": "https://..."
    }
  }
}
```

### Subcollection: `chatConversations/{conversationId}/messages`
```
{
  id: "msg123",
  senderId: "user1",
  text: "Hello!",
  imageUrl: null,
  timestamp: Timestamp,
  isRead: false,
  replyToId: null
}
```

---

## 🎨 UI Integration Examples

### Example 1: Add "Message" button to Profile Page
Already implemented in `social_profile_page.dart`:
```dart
OutlinedButton.icon(
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/social/chat',
      arguments: {'userId': widget.userId, 'profile': profile},
    );
  },
  icon: const Icon(Icons.chat_bubble_outline, size: 20),
  label: Text(l10n.message),
)
```

### Example 2: Navigate to Profile from PostCard
In `post_card.dart`, on user avatar tap:
```dart
GestureDetector(
  onTap: () {
    Navigator.pushNamed(
      context,
      '/social/profile',
      arguments: post.authorId,
    );
  },
  child: CircleAvatar(/* ... */),
)
```

---

## 🔒 Security Considerations

1. **Firestore Rules** - Cần thêm:
```javascript
match /socialPetProfiles/{userId} {
  allow read: if true; // Public profiles
  allow write: if request.auth.uid == userId; // Only owner can update
}

match /chatConversations/{conversationId} {
  allow read, write: if request.auth.uid in resource.data.participants;
}

match /chatConversations/{conversationId}/messages/{messageId} {
  allow read: if request.auth.uid in get(/databases/$(database)/documents/chatConversations/$(conversationId)).data.participants;
  allow create: if request.auth.uid == request.resource.data.senderId;
}
```

2. **Input Validation**:
- Sanitize user input (displayName, bio) to prevent XSS
- Validate image URLs before uploading
- Check message length limits

3. **Privacy**:
- Respect user blocking (TODO: add block feature)
- Allow users to make profiles private
- Report inappropriate content

---

## 🚀 Quick Start Guide

### Step 1: Test Profile Sync
1. Run app, navigate to Social tab
2. Check Firestore: should see `socialPetProfiles/{yourUserId}` document
3. Verify fields: displayName, avatarUrl, email, phone

### Step 2: View & Edit Profile
1. Navigate to profile page (need to add button in UI)
2. Tap "Edit Profile"
3. Change displayName, bio, upload new avatar
4. Save → check Firestore updates

### Step 3: Follow Users
1. View another user's profile
2. Tap "Follow" button
3. Check `followers` array in their profile
4. Check `following` array in your profile

### Step 4: Implement Chat UI (TODO)
1. Create `chat_bloc.dart` (see Task 9)
2. Create `chat_list_page.dart` (see Task 10)
3. Create `chat_room_page.dart` (see Task 11)
4. Add routes (see Task 12)
5. Add "Messages" icon to AppBar in `social_home_page.dart`

---

## 📱 UI Screenshots (Mockup)

### Profile Page Layout:
```
┌─────────────────────────────┐
│  ← Profile           ⚙      │
├─────────────────────────────┤
│   [Avatar]   10   150   50  │
│              Posts Follow... │
│                              │
│  Alice Nguyen                │
│  Pet lover 🐶                │
│  https://alice.com           │
│                              │
│  [Edit Profile]  [Message]  │
├─────────────────────────────┤
│  Posts | Followers | Follow..│
├─────────────────────────────┤
│  ┌───┬───┬───┐               │
│  │img│img│img│               │
│  ├───┼───┼───┤               │
│  │img│img│img│               │
│  └───┴───┴───┘               │
└─────────────────────────────┘
```

### Chat List Layout:
```
┌─────────────────────────────┐
│  ← Messages                  │
├─────────────────────────────┤
│  [O] Bob                  2m │
│      Hello there!         [3]│
├─────────────────────────────┤
│  [O] Charlie          1h ago │
│      See you tomorrow!       │
├─────────────────────────────┤
│  [O] Diana         Yesterday │
│      📷 Photo                 │
└─────────────────────────────┘
```

### Chat Room Layout:
```
┌─────────────────────────────┐
│  ← [O] Bob            Online │
├─────────────────────────────┤
│                              │
│  ┌───────────────┐           │
│  │ Hello there!  │  10:30 AM │
│  └───────────────┘           │
│                              │
│         ┌───────────────┐    │
│  11:00  │ Hi Bob! 👋   │    │
│         └───────────────┘    │
│                              │
│  ┌───────────────┐           │
│  │ How are you?  │  11:05 AM │
│  └───────────────┘           │
│                              │
├─────────────────────────────┤
│ [🙂] Type a message... [📷][>]│
└─────────────────────────────┘
```

---

## 📦 Dependencies Already Included
- `firebase_auth` - User authentication
- `cloud_firestore` - Database
- `firebase_storage` - Image upload
- `image_picker` - Select images
- `cached_network_image` - Image caching
- `flutter_bloc` - State management

---

## 🐛 Known Issues & TODOs

1. **Profile Cache**: Currently only loads visible profiles. Need to prefetch user profiles for posts/followers.
2. **Real-time Updates**: Chat needs StreamBuilder, profile updates need listeners.
3. **Pagination**: Posts grid and messages list need pagination for performance.
4. **Image Compression**: Large images should be compressed before upload.
5. **Offline Support**: Add local caching with Hive or SharedPreferences.
6. **Notifications**: Push notifications for new messages/followers.
7. **Search**: Search users by name/email in social network.
8. **Block/Report**: User safety features.

---

## 📞 Integration Points

### Where to Add Profile Button:
1. `social_home_page.dart` AppBar → Add IconButton(Icons.person) 
2. `post_card.dart` → Tap on author avatar
3. Bottom navigation → Add "Profile" tab

### Where to Add Chat Button:
1. `social_home_page.dart` AppBar → Add IconButton(Icons.chat)
2. `social_profile_page.dart` → "Message" button (already added)
3. Notification panel → Message alerts

---

**Last Updated:** December 2024  
**Status:** Backend complete, UI pending (Chat pages + Routing)
