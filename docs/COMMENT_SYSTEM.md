# Comment System - Hệ thống bình luận

## Tổng quan
Comment system là một phần quan trọng của Social Pet Network, cho phép người dùng tương tác và thảo luận về các bài viết.

## Kiến trúc

### 1. Domain Layer
- **Entity**: `SocialComment` trong `/lib/domain/entities/social_post.dart`
  - `id`: ID bình luận
  - `userId`: ID người dùng
  - `userName`: Tên người dùng
  - `userAvatarUrl`: URL avatar người dùng
  - `text`: Nội dung bình luận
  - `timestamp`: Thời gian đăng
  - `likes`: Danh sách user IDs đã like
  - `likeCount`: Số lượt like

### 2. Data Layer
- **Repository**: `SocialRepositoryImpl` trong `/lib/data/repositories/social_repository_impl.dart`
  - `addComment()`: Thêm bình luận mới
  - `deleteComment()`: Xóa bình luận
  - `likeComment()`: Like/Unlike bình luận
  - `getComments()`: Lấy danh sách bình luận

### 3. Presentation Layer

#### BLoC
- **Events** trong `/lib/presentation/bloc/social/social_event.dart`:
  - `AddComment`: Thêm bình luận mới
  - `DeleteComment`: Xóa bình luận
  - `LikeComment`: Like/Unlike bình luận
  - `LoadComments`: Tải danh sách bình luận

- **Handlers** trong `/lib/presentation/bloc/social/social_bloc.dart`:
  - `_onAddComment()`: Xử lý thêm bình luận
  - `_onDeleteComment()`: Xử lý xóa bình luận
  - `_onLikeComment()`: Xử lý like bình luận
  - `_onLoadComments()`: Xử lý tải bình luận

#### Widgets

##### CommentWidget
File: `/lib/presentation/widgets/social/comment_widget.dart`

**Tính năng:**
- Hiển thị avatar, tên người dùng
- Hiển thị nội dung bình luận trong bubble đẹp mắt
- Hiển thị thời gian đăng (format: Just now, 5m, 2h, 3d, etc.)
- Button Like với highlight khi đã like
- Button Reply để trả lời
- Button Delete (chỉ hiện cho chủ comment)

**Props:**
```dart
CommentWidget({
  required SocialComment comment,
  String? currentUserId,
  VoidCallback? onLike,
  VoidCallback? onReply,
  VoidCallback? onDelete,
})
```

##### CommentInput
File: `/lib/presentation/widgets/social/comment_widget.dart`

**Tính năng:**
- Input field với avatar người dùng
- Button Send để gửi
- Reply indicator khi đang trả lời ai đó
- Auto-clear sau khi gửi
- Support multiline text (1-5 lines)

**Props:**
```dart
CommentInput({
  String? currentUserAvatar,
  String? currentUserName,
  required Function(String) onSubmit,
  String? replyingTo,
  VoidCallback? onCancelReply,
})
```

#### Comment Bottom Sheet
Location: `/lib/presentation/pages/social/social_home_page.dart` - `_showCommentsSheet()`

**Tính năng:**
- DraggableScrollableSheet với 3 sizes (50%, 75%, 95%)
- Header với title "Comments" và close button
- Empty state đẹp với icon và message
- ListView scroll cho danh sách comments
- Fixed input ở bottom
- Support reply với @ mention
- Confirmation dialog khi xóa comment

**Flow:**
1. Tap vào comment button → Mở bottom sheet
2. Load comments từ Firestore
3. Hiển thị danh sách comments
4. User có thể:
   - Like comment
   - Reply comment
   - Delete own comments
   - Add new comment

## UI/UX Design

### Colors
- **Primary**: `#08A045` (light mode), `#4CAF50` (dark mode)
- **Comment bubble**: `Colors.grey[100]` (light), `Colors.grey[800]` (dark)
- **Like highlight**: Primary color khi đã like
- **Delete button**: `Colors.red[400]`

### Typography
- **Username**: 14px, Bold, Primary color
- **Comment text**: 14px, Normal, line-height 1.4
- **Timestamp**: 12px, Grey[600]
- **Actions (Like, Reply)**: 12px, Grey[600], Medium weight khi active

### Spacing
- Avatar size: 36px (radius 18)
- Horizontal padding: 16px
- Vertical padding: 8px
- Bubble padding: 12px horizontal, 8px vertical
- Bubble border radius: 16px

### Animations
- Smooth opening/closing của bottom sheet
- Instant update khi like (optimistic UI)
- Reload comments sau khi delete/add

## Internationalization (i18n)

### Vietnamese (`app_vi.arb`)
- `noCommentsYet`: "Chưa có bình luận"
- `beFirstToComment`: "Hãy là người đầu tiên bình luận!"
- `like`: "Thích"
- `reply`: "Trả lời"
- `delete`: "Xóa"
- `deleteComment`: "Xóa bình luận"
- `deleteCommentConfirm`: "Bạn có chắc chắn muốn xóa bình luận này?"
- `addComment`: "Thêm bình luận..."
- `viewComment`: "Xem 1 bình luận"
- `viewAllComments`: "Xem tất cả {count} bình luận"
- `justNow`: "Vừa xong"

### English (`app_en.arb`)
- `noCommentsYet`: "No comments yet"
- `beFirstToComment`: "Be the first to comment!"
- `like`: "Like"
- `reply`: "Reply"
- `delete`: "Delete"
- `deleteComment`: "Delete Comment"
- `deleteCommentConfirm`: "Are you sure you want to delete this comment?"
- `addComment`: "Add a comment..."
- `viewComment`: "View 1 comment"
- `viewAllComments`: "View all {count} comments"
- `justNow`: "Just now"

## Firestore Structure

```
socialPosts/{postId}/
  ├── comments (subcollection)/
      ├── {commentId}/
          ├── userId: string
          ├── userName: string
          ├── userAvatarUrl: string
          ├── text: string
          ├── timestamp: Timestamp
          ├── likes: array<string>
```

## Best Practices

### Performance
- Comments được load on-demand khi mở bottom sheet
- Chỉ reload comments khi có thay đổi (add, delete, like)
- Sử dụng BlocBuilder để optimize rebuild

### Security
- Chỉ chủ comment mới thấy nút Delete
- Validate user authentication trước khi thêm/xóa comment
- Server-side validation trong Firestore Rules

### User Experience
- Confirmation dialog trước khi xóa
- Loading state khi đang xử lý
- Empty state thân thiện
- Reply indicator rõ ràng
- Optimistic UI cho like

## Testing Checklist

- [ ] Add comment thành công
- [ ] Delete own comment
- [ ] Không thể delete comment của người khác
- [ ] Like/Unlike comment
- [ ] Reply với @ mention
- [ ] Empty state hiển thị đúng
- [ ] Timestamp format đúng
- [ ] Dark mode hoạt động tốt
- [ ] i18n switching hoạt động
- [ ] Bottom sheet drag smooth
- [ ] Multiline comment input

## Future Enhancements

1. **Reply Threading**: Comment replies thành thread riêng
2. **Edit Comment**: Cho phép chỉnh sửa comment
3. **Rich Text**: Support emoji, mentions, hashtags
4. **Load More**: Pagination cho nhiều comments
5. **Notifications**: Thông báo khi có reply/like
6. **Pin Comment**: Pin comment quan trọng lên đầu
7. **Report Comment**: Báo cáo comment vi phạm
