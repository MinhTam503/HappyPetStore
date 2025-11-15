# Fix Follow Stats Migration Guide

## Vấn đề

Dữ liệu Firestore bị lệch:
- `stats.followers = 3` nhưng `followers array` chỉ có 1 phần tử
- `stats.following = 0` nhưng `following array` có 1 phần tử
- Nguyên nhân: Code cũ không check duplicate follow → follow nhiều lần

## Giải pháp

### 1. Code đã fix (✅ Hoàn thành)

**Repository** (`social_repository_impl.dart`):
- ✅ `followPet()`: Check existing follow trước khi follow
- ✅ `unfollowPet()`: Check đã follow trước khi unfollow
- ✅ `getUserProfile()`: Auto-sync stats với array lengths

**BLoC** (`social_profile_page.dart`):
- ✅ Load profile → Check following status
- ✅ Hiển thị button đúng trạng thái

### 2. Chạy Migration để fix data hiện tại

**Option 1: Từ Debug Menu (Recommended)**

Thêm button vào Settings/Profile page:

```dart
import 'package:pet_shop/presentation/widgets/debug/fix_follow_stats_button.dart';

// Trong Settings hoặc Profile page
const FixFollowStatsButton()
```

**Option 2: Chạy script trực tiếp**

```dart
import 'package:pet_shop/data/migrations/fix_follow_stats.dart';

// Trong initState hoặc onPressed
await runAllMigrations();
```

**Option 3: Firebase Console**

Nếu không muốn code, có thể fix manual:

1. Mở Firebase Console → Firestore
2. Với mỗi document trong `socialPetProfiles`:
   - Count `followers` array → Update `stats.followers`
   - Count `following` array → Update `stats.following`

## Migration script làm gì?

### Step 1: Clean up duplicates
- Tìm tất cả follow duplicates
- Giữ lại unique followers
- Update array và stats

### Step 2: Sync stats with arrays
- So sánh `stats.followers` vs `followers.length`
- So sánh `stats.following` vs `following.length`
- Update stats nếu khác

## Testing

Sau khi chạy migration:

1. ✅ Vào profile người A → Followers đúng số
2. ✅ Vào profile của mình → Following đúng số
3. ✅ Follow người B → Followers tăng 1, Following tăng 1
4. ✅ Unfollow người B → Followers giảm 1, Following giảm 1
5. ✅ Follow lại → Không tăng duplicate
6. ✅ Button hiện đúng: "Theo dõi" hoặc "Đang theo dõi"

## Log output

Migration sẽ in log:
```
🔧 Starting stats synchronization...
📝 Fixing userId1:
   Followers: 3 → 1
   Following: 0 → 1
📝 Fixing userId2:
   Followers: 0 → 2
   Following: 1 → 3

✅ Migration complete!
   Fixed: 2 profiles
   Errors: 0 profiles
   Total: 10 profiles
```

## Lưu ý

- ⚠️ Chỉ cần chạy 1 lần
- ⚠️ Backup Firestore trước khi chạy (production)
- ✅ Safe để chạy nhiều lần (idempotent)
- ✅ Không xóa data, chỉ sync stats
