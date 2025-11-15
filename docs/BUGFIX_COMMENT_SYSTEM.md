# Bug Fixes Summary - Comment System

## Vấn đề đã fix (15/11/2025)

### 🐛 Bug 1: Post hiện 1 comment nhưng vào xem không thấy
**Nguyên nhân:** `LoadComments` event không được trigger khi mở comment sheet

**Giải pháp:**
```dart
void _showCommentsSheet(BuildContext context, String postId) {
  // Load comments when opening sheet
  context.read<SocialBloc>().add(LoadComments(postId));
  
  showModalBottomSheet(...);
}
```

**File changed:** `/lib/presentation/pages/social/social_home_page.dart`

---

### 🐛 Bug 2: Title dialog hiện "bình" thay vì "Comments"
**Nguyên nhân:** Code `AppLocalizations.of(context)!.comments(0).split(' ')[1]` lấy sai phần text

**Giải pháp:**
```dart
// BAD: AppLocalizations.of(context)!.comments(0).split(' ')[1]
// GOOD: 
const Text('Comments', ...)
```

**File changed:** `/lib/presentation/pages/social/social_home_page.dart`

---

### 🐛 Bug 3: Sau khi comment xong, tất cả posts biến mất
**Nguyên nhân:** `_onAddComment`, `_onDeleteComment`, `_onLikeComment` emit `SocialOperationSuccess` hoặc `SocialError` → state bị clear → mất hết posts

**Giải pháp:**
1. **Không emit states làm mất data:**
```dart
// BAD:
emit(const SocialOperationSuccess('Comment added'));
// GOOD:
// Just reload comments, don't emit success
add(LoadComments(event.postId));
```

2. **Preserve state khi load comments:**
```dart
Future<void> _onLoadComments(...) async {
  final comments = await _repository.getComments(event.postId);
  
  if (state is SocialLoaded) {
    // CRITICAL: Preserve all existing state
    final currentState = state as SocialLoaded;
    emit(currentState.copyWith(
      currentComments: comments,
      // Keep feed, exploreFeed, etc.
    ));
  }
}
```

**Files changed:** 
- `/lib/presentation/bloc/social/social_bloc.dart`
- Added `cloud_firestore` import

---

### 🐛 Bug 4: Thoát vào lại thì có post nhưng không thấy comment
**Nguyên nhân:** Kết hợp Bug 1 và Bug 3 - không load comments + state bị clear

**Giải pháp:** Đã fix ở Bug 1 và Bug 3

---

### 🐛 Bug 5: Comment không hiện tên và avatar người dùng
**Nguyên nhân:** `_onAddComment` hardcode `userName = 'User'` và `userAvatarUrl = ''`

**Giải pháp:**
```dart
Future<void> _onAddComment(...) async {
  // Get real user info from Firestore
  String userName = 'User';
  String userAvatarUrl = '';
  
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final userData = userDoc.data();
      userName = userData?['name'] ?? userData?['displayName'] ?? 'User';
      userAvatarUrl = userData?['avatar'] ?? userData?['photoURL'] ?? '';
    }
  } catch (e) {
    if (kDebugMode) print('⚠️ Could not fetch user info: $e');
  }
  
  await _repository.addComment(
    userName: userName,
    userAvatarUrl: userAvatarUrl,
    ...
  );
}
```

**File changed:** `/lib/presentation/bloc/social/social_bloc.dart`

---

## Cải tiến thêm

### ✨ Feature 1: Pull-to-refresh
**Added:** RefreshIndicator cho cả Following và Explore tabs

```dart
RefreshIndicator(
  onRefresh: () async {
    context.read<SocialBloc>().add(const LoadFeed(refresh: true));
  },
  child: ListView.builder(...),
)
```

### ✨ Feature 2: Error handling with retry
**Added:** Error state UI với nút "Try Again"

```dart
if (state is SocialError) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.error_outline, size: 64),
        Text('Oops! Something went wrong'),
        Text(state.message),
        ElevatedButton.icon(
          onPressed: () {
            context.read<SocialBloc>().add(const LoadFeed());
          },
          icon: Icon(Icons.refresh),
          label: Text('Try Again'),
        ),
      ],
    ),
  );
}
```

### ✨ Feature 3: Image loading states
**Added:** Loading và error builders cho images

```dart
Image.network(
  imageUrl,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.broken_image),
    );
  },
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator(
      value: loadingProgress.cumulativeBytesLoaded /
          loadingProgress.expectedTotalBytes!,
    );
  },
)
```

---

## Testing checklist

- [x] Open comment sheet → Comments load
- [x] Add comment → Comment appears, posts stay visible
- [x] Delete comment → Comment removed, posts stay visible
- [x] Like comment → Like count updates, posts stay visible
- [x] Close and reopen app → Posts and comments load correctly
- [x] Comment shows correct user name and avatar
- [x] Dialog title shows "Comments" correctly
- [x] Pull-to-refresh works on both tabs
- [x] Error state shows retry button
- [x] Image loading shows progress
- [x] Broken images show error icon

---

## Điểm quan trọng để nhớ

### ⚠️ CRITICAL: BLoC State Management
**KHÔNG BAO GIỜ** emit state mới mà không preserve data cũ:

```dart
// ❌ BAD - Mất hết posts
emit(SocialLoaded(currentComments: comments));

// ✅ GOOD - Giữ nguyên posts
if (state is SocialLoaded) {
  emit((state as SocialLoaded).copyWith(
    currentComments: comments,
  ));
}
```

### ⚠️ CRITICAL: Error Handling
**KHÔNG** emit `SocialError` trong các operation nhỏ (add/delete/like comment) vì sẽ clear màn hình:

```dart
// ❌ BAD
catch (e) {
  emit(SocialError(e.toString())); // Clears posts!
}

// ✅ GOOD
catch (e) {
  if (kDebugMode) print('Error: $e');
  // Keep current state, just log error
}
```

### ⚠️ Best Practice: Always trigger LoadComments
Sau mọi thao tác comment (add/delete/like), luôn reload:

```dart
await _repository.addComment(...);
// Don't emit success
add(LoadComments(event.postId)); // Reload to show changes
```

---

## Files Modified

1. `/lib/presentation/bloc/social/social_bloc.dart`
   - Added `cloud_firestore` import
   - Fixed `_onAddComment()` - fetch real user info
   - Fixed `_onDeleteComment()` - no error emit
   - Fixed `_onLikeComment()` - no error emit
   - Fixed `_onLoadComments()` - preserve state with copyWith

2. `/lib/presentation/pages/social/social_home_page.dart`
   - Fixed dialog title
   - Added `LoadComments` call when opening sheet
   - Added error states with retry for both tabs
   - Added RefreshIndicator for Explore tab
   - Added image error/loading builders

---

## Performance Impact

✅ **Positive:**
- Comments load immediately when opening sheet
- State preservation prevents unnecessary rebuilds
- Image loading shows progress → better UX
- Error handling prevents blank screens

⚠️ **Watch out:**
- Each comment action triggers full comments reload
  - Consider optimistic updates in future
  - Consider pagination for many comments

---

## Future Improvements

1. **Optimistic UI Updates:**
   - Update UI immediately, sync with backend later
   - Show skeleton loaders during sync

2. **Comment Pagination:**
   - Load comments in batches (e.g., 20 at a time)
   - "Load more" button for older comments

3. **Real-time Updates:**
   - Use Firestore listeners for live comments
   - Push notifications for new comments

4. **Offline Support:**
   - Cache comments locally
   - Queue operations when offline

5. **Analytics:**
   - Track comment engagement
   - Monitor error rates
