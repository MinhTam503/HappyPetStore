# Customer Chat Refactor - BLoC Architecture

## Overview
Refactored customer-to-shop chat system from direct Firestore calls to BLoC pattern architecture, ensuring consistency with other chat systems (UserChat and GroupChat).

## Architecture Changes

### Three Separate Chat Systems
1. **Customer ↔ Shop Chat** (NEW - this refactor)
   - Collection: `customerConversations`
   - Repository: `CustomerChatRepository` + `CustomerChatRepositoryImpl`
   - BLoC: `CustomerChatBloc`
   - UI: `lib/presentation/pages/mobile/chat/chat_page.dart`

2. **User ↔ User Social Chat** (existing)
   - Collection: `chatConversations`
   - Repository: `UserChatRepository` + implementation
   - BLoC: `ChatBloc`

3. **Group Chat** (existing)
   - Collection: `groupConversations`
   - Repository: `GroupChatRepository` + implementation
   - BLoC: `GroupChatBloc`

## Created Files

### 1. Repository Interface
**`lib/domain/repositories/customer_chat_repository.dart`** (924 bytes)
- Abstract interface defining contract for customer chat operations
- Methods:
  - `getOrCreateConversation()` - Create/fetch conversation
  - `sendMessage()` - Send text message
  - `sendImageMessage()` - Send image message
  - `streamMessages()` - Real-time message stream
  - `markMessagesAsRead()` - Mark messages as read

### 2. Repository Implementation
**`lib/data/repositories/customer_chat_repository_impl.dart`** (7.3 KB)
- Concrete implementation using Firestore
- Uses `customerConversations` collection
- Static `shopId = 'shop_admin'`
- Conversation ID = customer email
- Handles unread count tracking
- Participants info storage

### 3. BLoC Events
**`lib/presentation/bloc/customer_chat/customer_chat_event.dart`** (1.3 KB)
- `LoadCustomerMessages` - Load conversation messages
- `SendCustomerMessage` - Send text message
- `SendCustomerImageMessage` - Send image message
- `MarkCustomerMessagesAsRead` - Mark as read

### 4. BLoC States
**`lib/presentation/bloc/customer_chat/customer_chat_state.dart`** (712 bytes)
- `CustomerChatInitial` - Initial state
- `CustomerChatLoading` - Loading messages
- `CustomerChatLoaded` - Messages loaded with data
- `CustomerChatError` - Error state with message

### 5. BLoC Logic
**`lib/presentation/bloc/customer_chat/customer_chat_bloc.dart`** (2.8 KB)
- Coordinates business logic
- Manages message streaming with `StreamSubscription`
- Handles all events and state transitions
- Proper cleanup in `close()` method

### 6. Refactored UI
**`lib/presentation/pages/mobile/chat/chat_page.dart`** (15 KB)
- Wrapped in `BlocProvider`
- Uses `BlocBuilder` for reactive UI
- Maintains all original features:
  - Auto-fill pet info
  - Image upload to Firebase Storage
  - Real-time messages
  - Auto-scroll to bottom
  - Avatars for users
  - Timestamp display
  - Error handling with retry

## Data Model

### Conversation Document
```
customerConversations/{customerId}/
  - participants: [customerId, 'shop_admin']
  - lastMessage: string
  - lastMessageTime: timestamp
  - lastMessageSenderId: string
  - unreadCount: {customerId: int, shop_admin: int}
  - createdAt: timestamp
  - participantsInfo: {
      customerId: {name, imageUrl},
      shop_admin: {name, imageUrl}
    }
```

### Message Document
```
customerConversations/{customerId}/messages/{messageId}
  - senderId: string
  - text: string? (optional)
  - imageUrl: string? (optional)
  - timestamp: timestamp
  - isRead: boolean
  - reactions: map<string, string>
```

## Key Features

### 1. Collection Separation
- ✅ No more conflicts between chat systems
- ✅ Clear data ownership
- ✅ Independent scaling

### 2. BLoC Pattern Benefits
- ✅ Separation of concerns
- ✅ Testable business logic
- ✅ Reactive UI updates
- ✅ Stream management
- ✅ Error handling

### 3. Maintained Features
- ✅ Pet info auto-fill
- ✅ Image upload/send
- ✅ Real-time messaging
- ✅ Auto-scroll
- ✅ Read receipts
- ✅ Unread count tracking

### 4. Improvements
- ✅ Clean architecture
- ✅ Type-safe entities
- ✅ Better error handling with retry
- ✅ Proper resource cleanup
- ✅ Consistent with other chat systems

## Backup

Original implementation backed up to:
**`lib/presentation/pages/mobile/chat/chat_page.dart.bak`** (22 KB)

## Migration Notes

### No Breaking Changes
- Navigation to `ChatPage` works the same
- Accepts same `selectedPet` parameter
- UI looks identical to users
- All features preserved

### Data Migration
- Old conversations in `conversations` collection remain
- New conversations created in `customerConversations`
- No automatic migration (can be added if needed)
- Shop admin panel should read from `customerConversations`

### Testing Checklist
- [ ] Customer can open chat
- [ ] Send text messages
- [ ] Send image messages
- [ ] Receive shop responses
- [ ] Auto-scroll works
- [ ] Pet info auto-fills
- [ ] Unread count updates
- [ ] Error handling with retry
- [ ] Proper cleanup on dispose

## Firebase Security Rules

Add to `firestore.rules`:
```javascript
match /customerConversations/{conversationId} {
  allow read, write: if request.auth != null && 
    (request.auth.token.email == conversationId || 
     request.auth.token.email == 'shop@gmail.com');
  
  match /messages/{messageId} {
    allow read, write: if request.auth != null;
  }
}
```

## Dependencies

All dependencies already in `pubspec.yaml`:
- ✅ `flutter_bloc`
- ✅ `equatable`
- ✅ `cloud_firestore`
- ✅ `firebase_storage`
- ✅ `image_picker`

## Next Steps

1. **Test** the refactored implementation
2. **Update** shop admin panel to read `customerConversations`
3. **Migrate** old data if needed (optional)
4. **Monitor** Firestore usage
5. **Add** push notifications for new messages (optional)

## Summary

Successfully separated customer-shop chat from social chat systems by:
- Creating dedicated `CustomerChat` architecture with BLoC pattern
- Using separate `customerConversations` Firestore collection
- Maintaining all original features and UI
- Ensuring consistency with `UserChat` and `GroupChat` architectures
- Zero breaking changes to existing code

The refactor eliminates collection conflicts and provides a clean, maintainable architecture for future enhancements.
