# Mô tả Chi tiết Các Bộ Sưu Tập Firestore - HappyPetStore

## 1.1.1. Mô tả tổng quát các bộ sưu tập (collection)

**Bảng 1.1: Bảng mô tả tổng quát các bộ sưu tập (collection)**

| STT | Tên bộ sưu tập | Mô tả |
|-----|----------------|-------|
| 1 | Users | Lưu thông tin người dùng |
| 2 | Pets | Lưu thông tin thú cưng |
| 3 | Category | Lưu thông tin danh mục và giống thú cưng |
| 4 | Orders | Lưu thông tin đơn hàng |
| 5 | Notifications | Lưu thông báo của từng người dùng |
| 6 | Favorites | Lưu thông tin thú cưng yêu thích của người dùng |
| 7 | Conversations | Lưu các cuộc trò chuyện của người dùng với cửa hàng |
| 8 | Carts | Lưu thú cưng người dùng đã thêm vào giỏ hàng |
| 9 | ViewedPets | Lưu thông tin thú cưng người dùng đã xem |
| 10 | ShopInfo | Lưu thông tin cửa hàng |
| 11 | SearchHistory | Lưu thông tin tìm kiếm của người dùng |
| 12 | ordersWeb | Lưu đơn hàng từ giao diện web admin |
| 13 | Breed | Lưu chi tiết danh sách giống thú cưng theo danh mục |
| 14 | chatConversations | Lưu cuộc trò chuyện 1-1 giữa người dùng |
| 15 | groupConversations | Lưu cuộc trò chuyện nhóm cộng đồng |
| 16 | socialPosts | Lưu bài viết mạng xã hội |
| 17 | socialPetProfiles | Lưu hồ sơ thú cưng/người dùng trong mạng xã hội |
| 18 | socialFollows | Lưu thông tin theo dõi giữa người dùng |
| 19 | socialSettings | Lưu cài đặt quyền riêng tư mạng xã hội |
| 20 | blockedUsers | Lưu danh sách người dùng bị chặn |
| 21 | sensitiveWords | Lưu từ ngữ nhạy cảm cần kiểm duyệt |
| 22 | UserFav | Lưu sở thích người dùng phục vụ gợi ý |

---

## 1.1.2. Mô tả chi tiết các bộ sưu tập (collection)

### **Bảng 1.2: Bộ sưu tập danh mục (Category)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| name | chuỗi (string) | Tên tên danh mục thú cưng |
| imageUrl | chuỗi (string) | Ảnh danh mục thú cưng |
| breeds | mảng (array) | Chứa danh sách tên giống của danh mục thú cưng đó |

---

### **Bảng 1.3: Bộ sưu tập tài khoản người dùng (Users)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| address | mảng (array) | Lưu danh sách địa chỉ của người dùng (nếu có). Mỗi phần tử có thể chứa thông tin như tên người nhận, số điện thoại, địa chỉ cụ thể. |
| authProvider | chuỗi (string) | Nguồn xác thực của người dùng "phone", "Google", "Facebook". |
| createdAt | dấu thời gian (timestamp) | Thời điểm tài khoản người dùng được tạo trên hệ thống. |
| deliveryInfos | mảng (array) | Lưu các thông tin giao hàng của người dùng, có thể gồm địa chỉ nhận, ghi chú hoặc phương thức vận chuyển. |
| displayName | chuỗi (string) | Tên hiển thị của người dùng trong ứng dụng. |
| email | chuỗi (string) | Địa chỉ email của người dùng (nếu có). |
| emailVerified | boolean (true/false) | Xác định email đã được xác minh hay chưa. |
| fcmTokenPlatform | chuỗi (string) | Nền tảng nhận thông báo FCM, ví dụ "android" hoặc "iOS". |
| fcmTokenUpdatedAt | dấu thời gian (timestamp) | Thời điểm cập nhật token FCM gần nhất. |
| fcmTokens | mảng (array) | Danh sách các token FCM mà thiết bị người dùng đang sử dụng để nhận thông báo đẩy. |
| gender | null hoặc chuỗi (string) | Giới tính của người dùng (có thể chưa được khai báo). |
| imageUrl | chuỗi (string) | Đường dẫn ảnh đại diện của người dùng được lưu trên Firebase Storage. |
| lastFcmToken | chuỗi (string) | Token FCM gần nhất được sử dụng để gửi thông báo đến người dùng. |
| phone | chuỗi (string) | Số điện thoại của người dùng, thường là định danh chính khi đăng nhập bằng "phone". |
| role | chuỗi (string) | Vai trò của người dùng trong hệ thống. |

---

### **Bảng 1.4: Bộ sưu tập đơn hàng (Orders)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| orderId | chuỗi (string) | Mã đơn hàng duy nhất. |
| userId | chuỗi (string) | ID người dùng trên hệ thống (UID Firebase Auth). |
| userIdentifier | chuỗi (string) | Định danh người dùng (thường trùng userId, dùng cho truy vấn nhanh). |
| customerInfo | bản đồ (map) | Thông tin khách đặt: gồm name, email, phone. |
| deliveryInfo | bản đồ (map) | Thông tin giao hàng: name, phone, address, latitude, longitude, isDefault. |
| items | mảng (array) | Danh sách các sản phẩm/thú cưng trong đơn (mỗi phần tử là map, xem bảng "Item" bên dưới). |
| paymentMethod | chuỗi (string) | Phương thức thanh toán. |
| statusOrder | chuỗi (string) | Trạng thái đơn hàng. |
| statusPayment | chuỗi (string) | Trạng thái thanh toán. |
| shippingAddress | chuỗi (string) | Địa chỉ giao hàng (bản sao nhanh từ deliveryInfo.address). |
| phone | chuỗi (string) | Số điện thoại liên hệ (bản sao nhanh từ deliveryInfo.phone). |
| shippingFee | số (number) | Phí vận chuyển (VND). |
| subtotal | số (number) | Tạm tính (tổng tiền các item trước phí/giảm giá). |
| totalAmount | số (number) | Tổng thanh toán sau cùng. |
| timestamp | dấu thời gian (timestamp) | Thời điểm tạo hoặc chốt đơn. |
| displayName | chuỗi (string) | (Tuỳ chọn) Tên hiển thị khách hàng ở mức root, phục vụ hiển thị nhanh. |
| email | chuỗi (string) | (Tuỳ chọn) Email khách hàng ở mức root, phục vụ hiển thị/tra cứu nhanh. |

---

### **Bảng 1.5: Chi tiết thông tin khách hàng trong đơn hàng (customerInfo)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| name | chuỗi (string) | Tên khách đặt. |
| email | chuỗi (string) | Email khách đặt. |
| phone | chuỗi (string) | Số điện thoại khách đặt. |

---

### **Bảng 1.6: Chi tiết thông tin vận chuyển trong đơn hàng (deliveryInfo)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| name | chuỗi (string) | Tên người nhận. |
| phone | chuỗi (string) | Số điện thoại người nhận. |
| address | chuỗi (string) | Địa chỉ giao hàng. |
| latitude | số (number) | Vĩ độ. |
| longitude | số (number) | Kinh độ. |
| isDefault | boolean (true/false) | Địa chỉ mặc định hay không. |

---

### **Bảng 1.7: Bộ sưu tập thông báo (notifications)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| id | chuỗi (string) | ID duy nhất của thông báo (Firebase document ID). |
| title | chuỗi (string) | Tiêu đề ngắn của thông báo. |
| content | chuỗi (string) | Nội dung chi tiết của thông báo gửi đến người dùng. |
| type | chuỗi (string) | Loại thông báo |
| isRead | boolean (true/false) | Trạng thái đã đọc của thông báo (mặc định là false). |
| createdAt | dấu thời gian (timestamp) | Thời điểm thông báo được tạo. |
| userId | chuỗi (string) | ID người dùng nhận thông báo. |
| data | bản đồ (map) | Chứa thông tin liên quan đến sự kiện như orderId, customerName, estimatedDelivery. |

---

### **Bảng 1.8: Bộ sưu tập yêu thích (Favorites)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| items | mảng (array) | Danh sách thú cưng/sản phẩm mà người dùng đã đánh dấu yêu thích. Mỗi phần tử là một map (xem bảng "item" bên dưới). |

---

### **Bảng 1.9: Cấu trúc mỗi phần tử trong bộ sưu tập yêu thích (items)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| productId | chuỗi (string) | ID của thú cưng/sản phẩm trong hệ thống. |
| name | chuỗi (string) | Tên thú cưng. |
| imageUrl | chuỗi (string) | Đường dẫn ảnh minh họa từ Firebase Storage. |
| price | số (number) | Giá của thú cưng tại thời điểm được yêu thích (VND). |
| createdAt | chuỗi (string) | Thời gian yêu thích (dạng ISO string). |
| createdAtMillis | số (number) | Thời gian yêu thích. |

---

### **Bảng 1.10: Bộ sưu tập thú cưng đã xem (ViewedPets)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| petId | chuỗi (string) | ID thú cưng được xem (trùng productId trong kho). |
| name | chuỗi (string) | Tên thú cưng. |
| imageUrl | chuỗi (string) | Ảnh đại diện của thú cưng. |
| category | chuỗi (string) | Danh mục thú cưng. |
| breed | chuỗi (string) | Giống của thú cưng. |
| price | số (number) | Giá của thú cưng (VND). |
| viewedAt | thời gian (timestamp) | Thời điểm người dùng xem thú cưng. |
| viewedAtMillis | số (number) | Thời gian xem ở dạng milliseconds (phục vụ thống kê, sắp xếp nhanh). |

---

### **Bảng 1.11: Bộ sưu tập cuộc trò chuyện (Conversations)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| lastMessage | chuỗi (string) | Nội dung tin nhắn cuối cùng trong cuộc trò chuyện. Dùng để hiển thị xem trước hội thoại trong danh sách. |
| participants | mảng (array) | Danh sách những người tham gia cuộc trò chuyện, thường gồm hai email: người dùng và cửa hàng (hoặc quản trị viên). |
| timestamp | thời gian (timestamp) | Thời điểm cập nhật tin nhắn cuối cùng hoặc tạo cuộc trò chuyện. |
| messages | bộ sưu tập con (subcollection) | Lưu danh sách nội dung tin nhắn |

---

### **Bảng 1.12: Bộ sưu tập tin nhắn (subcollection messages)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| message | chuỗi (string) | Nội dung tin nhắn được gửi trong cuộc trò chuyện. |
| imageUrl | chuỗi (string) | Ảnh đại diện của người dùng đính kèm trong tin nhắn, được lưu trên Firebase Storage. |
| sender | chuỗi (string) | Email hoặc ID của người gửi tin nhắn. |
| timestamp | dấu thời gian (timestamp) | Thời điểm gửi tin nhắn. |

---

### **Bảng 1.13: Bộ sưu tập giỏ hàng (Carts)**

| Trường (Field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| items | mảng (array) | Danh sách các thú cưng/sản phẩm mà người dùng đã thêm vào giỏ hàng. Mỗi phần tử là một map (xem bảng "item" bên dưới). |
| selectedProductIds | mảng (array) | Danh sách các productId mà người dùng đã chọn để tiến hành thanh toán (trạng thái "được chọn" trong UI). |

---

### **Bảng 1.14: Cấu trúc mỗi phần tử trong bộ sưu tập giỏ hàng (items)**

| Trường (Field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| productId | chuỗi (string) | ID sản phẩm/thú cưng được thêm vào giỏ hàng. |
| name | chuỗi (string) | Tên thú cưng. |
| breed | chuỗi (string) | Giống thú cưng. |
| color | chuỗi (string) | Màu sắc của thú cưng (có thể trống nếu không có thông tin). |
| gender | chuỗi (string) | Giới tính thú cưng "Male" hoặc "Female". |
| price | số (number) | Giá của thú cưng tại thời điểm thêm vào giỏ hàng (VND). |
| quantity | số (number) | Số lượng (mặc định là 1). |
| imageUrl | chuỗi (string) | Ảnh đại diện thú cưng. |
| createdAt | chuỗi (string) | Thời gian thêm vào giỏ hàng (dạng ISO string). |
| createdAtMillis | số (number) | Thời gian thêm vào giỏ hàng (dạng epoch milliseconds). |

---

### **Bảng 1.15: Bộ sưu tập thông tin cửa hàng (ShopInfo)**

| Trường (Field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| name | chuỗi (string) | Tên cửa hàng. |
| about | chuỗi (string) | Giới thiệu ngắn về cửa hàng, mô tả sản phẩm và dịch vụ cung cấp. |
| address | chuỗi (string) | Địa chỉ cụ thể của cửa hàng. |
| avatar | chuỗi (string) | Đường dẫn ảnh đại diện của cửa hàng (Firebase Storage URL). |
| googleMapsUrl | chuỗi (string) | Liên kết định vị Google Maps của cửa hàng. |
| latitude | số (number) | Vĩ độ của vị trí cửa hàng. |
| longitude | số (number) | Kinh độ của vị trí cửa hàng. |

---

### **Bảng 1.16: Bộ sưu tập lịch sử tìm kiếm (SearchHistory)**

| Trường (Field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| query | chuỗi (string) | Từ khóa người dùng đã tìm kiếm. |
| queryLower | chuỗi (string) | Phiên bản chữ thường của từ khóa, dùng cho tìm kiếm không phân biệt hoa/thường. |
| imageUrl | chuỗi (string) hoặc null | Đường dẫn ảnh của kết quả nếu tìm kiếm qua hình ảnh, ngược lại là null. |
| isImageSearch | boolean (true/false) | Cho biết đây có phải tìm kiếm bằng hình ảnh hay không. |
| searchedAt | dấu thời gian (timestamp) | Thời điểm thực hiện tìm kiếm. |
| searchedAtMillis | số (number) | Thời gian tìm kiếm ở dạng 1000 (milli) giây (phục vụ thống kê, sắp xếp nhanh). |

---

## Các Bộ Sưu Tập Bổ Sung

### **Bảng 1.17: Bộ sưu tập đơn hàng từ web (ordersWeb)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| orderId | chuỗi (string) | Mã đơn hàng duy nhất |
| userId | chuỗi (string) | ID người dùng trên hệ thống (UID Firebase Auth) |
| userIdentifier | chuỗi (string) | Định danh người dùng (thường trùng userId, dùng cho truy vấn nhanh) |
| customerInfo | bản đồ (map) | Thông tin khách đặt: gồm name, email, phone |
| deliveryInfo | bản đồ (map) | Thông tin giao hàng: name, phone, address, latitude, longitude, isDefault |
| items | mảng (array) | Danh sách các sản phẩm/thú cưng trong đơn (mỗi phần tử là map) |
| paymentMethod | chuỗi (string) | Phương thức thanh toán |
| statusOrder | chuỗi (string) | Trạng thái đơn hàng |
| statusPayment | chuỗi (string) | Trạng thái thanh toán |
| shippingAddress | chuỗi (string) | Địa chỉ giao hàng (bản sao nhanh từ deliveryInfo.address) |
| phone | chuỗi (string) | Số điện thoại liên hệ (bản sao nhanh từ deliveryInfo.phone) |
| shippingFee | số (number) | Phí vận chuyển (VND) |
| subtotal | số (number) | Tạm tính (tổng tiền các item trước phí/giảm giá) |
| totalAmount | số (number) | Tổng thanh toán sau cùng |
| timestamp | dấu thời gian (timestamp) | Thời điểm tạo hoặc chốt đơn |
| shippingInfo | bản đồ (map) | Thông tin vận chuyển chi tiết bao gồm status, trackingNumber, trackingHistory |
| trackingNumber | chuỗi (string) | Mã vận đơn dùng để theo dõi |

**Lưu ý:** Bộ sưu tập này có cấu trúc tương tự hoàn toàn với `Orders`, nhưng dành riêng cho các đơn hàng được tạo từ giao diện quản trị web (web admin), phục vụ phân tách và quản lý dữ liệu giữa ứng dụng mobile và web.

---

### **Bảng 1.18: Bộ sưu tập giống thú cưng (Breed)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| (Document ID) | chuỗi (string) | ID của document chính là tên danh mục thú cưng (ví dụ: "Chó", "Mèo") |
| breeds | mảng (array) | Danh sách các giống thú cưng thuộc danh mục này (ví dụ: ["Poodle", "Golden Retriever", "Chihuahua"]) |

**Lưu ý:** Collection này bổ sung chi tiết cho việc quản lý giống thú cưng, tách riêng khỏi collection `Category` để dễ dàng thêm, sửa, xóa các giống mà không ảnh hưởng đến dữ liệu danh mục chính.

---

### **Bảng 1.19: Bộ sưu tập cuộc trò chuyện 1-1 (chatConversations)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| participants | mảng (array) | Danh sách ID của hai người tham gia cuộc trò chuyện (hai user IDs) |
| lastMessage | chuỗi (string) | Nội dung tin nhắn cuối cùng trong cuộc trò chuyện |
| lastMessageTime | dấu thời gian (timestamp) | Thời điểm tin nhắn cuối cùng được gửi |
| lastMessageSenderId | chuỗi (string) | ID người gửi tin nhắn cuối cùng |
| unreadCount | bản đồ (map) | Số tin nhắn chưa đọc của từng người (userId → số lượng chưa đọc) |
| createdAt | dấu thời gian (timestamp) | Thời điểm tạo cuộc trò chuyện |
| messages | bộ sưu tập con (subcollection) | Lưu danh sách tin nhắn trong cuộc trò chuyện |

**Lưu ý:** Bộ sưu tập này khác với `Conversations` (trò chuyện giữa người dùng với cửa hàng). `chatConversations` dành cho cuộc trò chuyện 1-1 giữa các người dùng với nhau trong tính năng mạng xã hội.

---

### **Bảng 1.20: Bộ sưu tập tin nhắn 1-1 (subcollection messages trong chatConversations)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| senderId | chuỗi (string) | ID người gửi tin nhắn |
| text | chuỗi (string) | Nội dung văn bản của tin nhắn |
| imageUrl | chuỗi (string) | Đường dẫn ảnh đính kèm (nếu có), lưu trên Firebase Storage |
| timestamp | dấu thời gian (timestamp) | Thời điểm gửi tin nhắn |
| readBy | mảng (array) | Danh sách user IDs đã đọc tin nhắn này |
| reactions | bản đồ (map) | Phản ứng emoji của người dùng (userId → emoji) |

---

### **Bảng 1.21: Bộ sưu tập cuộc trò chuyện nhóm (groupConversations)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| name | chuỗi (string) | Tên nhóm chat |
| avatarUrl | chuỗi (string) | Ảnh đại diện của nhóm (Firebase Storage URL) |
| participants | mảng (array) | Danh sách user IDs của các thành viên trong nhóm |
| createdBy | chuỗi (string) | User ID của người tạo nhóm |
| isPublic | boolean (true/false) | Nhóm công khai (true) hay riêng tư (false) |
| lastMessage | chuỗi (string) | Nội dung tin nhắn cuối cùng |
| lastMessageTime | dấu thời gian (timestamp) | Thời điểm tin nhắn cuối cùng |
| lastMessageSenderId | chuỗi (string) | ID người gửi tin nhắn cuối cùng |
| unreadCount | bản đồ (map) | Số tin nhắn chưa đọc của từng thành viên (userId → số lượng) |
| createdAt | dấu thời gian (timestamp) | Thời điểm tạo nhóm |
| participantsInfo | bản đồ (map) | Thông tin chi tiết của thành viên (userId → {name, avatar}) |
| admins | mảng (array) | Danh sách user IDs của các quản trị viên nhóm |
| messages | bộ sưu tập con (subcollection) | Lưu danh sách tin nhắn trong nhóm |

**Lưu ý:** Collection này dành cho các nhóm cộng đồng trong tính năng mạng xã hội, cho phép nhiều người cùng trò chuyện trong một nhóm.

---

### **Bảng 1.22: Bộ sưu tập tin nhắn nhóm (subcollection messages trong groupConversations)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| groupId | chuỗi (string) | ID của nhóm chat |
| senderId | chuỗi (string) | ID người gửi tin nhắn |
| text | chuỗi (string) | Nội dung văn bản của tin nhắn |
| imageUrl | chuỗi (string) | Đường dẫn ảnh đính kèm (nếu có) |
| timestamp | dấu thời gian (timestamp) | Thời điểm gửi tin nhắn |
| readBy | bản đồ (map) | Trạng thái đã đọc của từng thành viên (userId → true/false) |
| replyToId | chuỗi (string) | ID của tin nhắn được trả lời (nếu là tin nhắn reply) |
| reactions | bản đồ (map) | Phản ứng emoji (userId → emoji) |
| isSystemMessage | boolean (true/false) | Tin nhắn hệ thống (thông báo tham gia/rời nhóm) hay không |

---

### **Bảng 1.23: Bộ sưu tập bài viết mạng xã hội (socialPosts)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| petId | chuỗi (string) | ID của hồ sơ thú cưng/người dùng đăng bài |
| authorId | chuỗi (string) | ID người đăng bài (owner của pet profile) |
| imageUrls | mảng (array) | Danh sách đường dẫn ảnh trong bài đăng (Firebase Storage URLs) |
| videoUrl | chuỗi (string) | Đường dẫn video đính kèm (nếu có) |
| caption | chuỗi (string) | Nội dung mô tả của bài đăng |
| likes | mảng (array) | Danh sách user IDs đã thích bài viết này |
| comments | mảng (array) | Danh sách bình luận (mỗi phần tử chứa: id, postId, userId, userName, userAvatarUrl, text, likes, timestamp) |
| location | bản đồ (map) | Vị trí đăng bài (city, country, latitude, longitude) |
| tags | mảng (array) | Danh sách hashtags hoặc tags gắn với bài viết |
| timestamp | dấu thời gian (timestamp) | Thời điểm đăng bài |
| viewCount | số (number) | Số lượt xem bài viết |

---

### **Bảng 1.24: Cấu trúc bình luận trong bài viết (comments trong socialPosts)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| id | chuỗi (string) | ID duy nhất của bình luận |
| postId | chuỗi (string) | ID của bài viết được bình luận |
| userId | chuỗi (string) | ID người bình luận |
| userName | chuỗi (string) | Tên hiển thị của người bình luận |
| userAvatarUrl | chuỗi (string) | Ảnh đại diện của người bình luận |
| text | chuỗi (string) | Nội dung bình luận |
| likes | mảng (array) | Danh sách user IDs đã thích bình luận này |
| timestamp | dấu thời gian (timestamp) | Thời điểm bình luận |
| parentId | chuỗi (string) | ID của bình luận cha (nếu là bình luận trả lời) |
| replies | mảng (array) | Danh sách các bình luận trả lời |

---

### **Bảng 1.25: Bộ sưu tập hồ sơ mạng xã hội (socialPetProfiles)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| id | chuỗi (string) | User ID (dùng làm ID hồ sơ) |
| ownerId | chuỗi (string) | User ID của chủ sở hữu hồ sơ (thường trùng với id) |
| petName | chuỗi (string) | Tên hiển thị (có thể là tên người dùng hoặc tên thú cưng) |
| breed | chuỗi (string) | Giống thú cưng |
| category | chuỗi (string) | Danh mục thú cưng |
| avatarUrl | chuỗi (string) | Ảnh đại diện hồ sơ (Firebase Storage URL) |
| bio | chuỗi (string) | Tiểu sử/Giới thiệu bản thân |
| followers | mảng (array) | Danh sách user IDs đang theo dõi hồ sơ này |
| following | mảng (array) | Danh sách user IDs mà hồ sơ này đang theo dõi |
| stats | bản đồ (map) | Thống kê (posts, followers, following, totalLikes, totalComments) |
| createdAt | dấu thời gian (timestamp) | Thời điểm tạo hồ sơ |
| isPublic | boolean (true/false) | Hồ sơ công khai (true) hay riêng tư (false) |
| displayName | chuỗi (string) | Tên hiển thị từ collection Users (đồng bộ) |
| email | chuỗi (string) | Email người dùng (đồng bộ từ Users) |
| phone | chuỗi (string) | Số điện thoại (đồng bộ từ Users) |
| website | chuỗi (string) | Website cá nhân |

**Lưu ý:** Collection này đồng bộ thông tin từ collection `Users` nhưng có thêm các trường đặc thù cho tính năng mạng xã hội như followers, following, stats.

---

### **Bảng 1.26: Cấu trúc thống kê trong hồ sơ mạng xã hội (stats trong socialPetProfiles)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| posts | số (number) | Tổng số bài viết đã đăng |
| followers | số (number) | Tổng số người theo dõi |
| following | số (number) | Tổng số người đang theo dõi |
| totalLikes | số (number) | Tổng số lượt thích nhận được |
| totalComments | số (number) | Tổng số bình luận nhận được |

---

### **Bảng 1.27: Bộ sưu tập theo dõi mạng xã hội (socialFollows)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| (Document ID) | chuỗi (string) | User ID của người dùng |
| followers | mảng (array) | Danh sách user IDs đang theo dõi người dùng này |
| following | mảng (array) | Danh sách user IDs mà người dùng này đang theo dõi |

**Lưu ý:** Collection này lưu trữ mối quan hệ theo dõi giữa các người dùng, mỗi document đại diện cho một người dùng với hai danh sách: người theo dõi họ và người họ theo dõi.

---

### **Bảng 1.28: Bộ sưu tập cài đặt mạng xã hội (socialSettings)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| (Document ID) | chuỗi (string) | User ID của người dùng |
| accountPrivate | boolean (true/false) | Tài khoản riêng tư (true) hay công khai (false) |
| showFollowersToPublic | boolean (true/false) | Hiển thị danh sách người theo dõi cho công chúng |
| showFollowingToPublic | boolean (true/false) | Hiển thị danh sách đang theo dõi cho công chúng |
| allowComments | boolean (true/false) | Cho phép bình luận trên bài viết |

**Lưu ý:** Collection này lưu các tùy chọn quyền riêng tư và cài đặt hiển thị của người dùng trong mạng xã hội.

---

### **Bảng 1.29: Bộ sưu tập người dùng bị chặn (blockedUsers)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| (Document ID) | chuỗi (string) | User ID của người dùng |
| blocked | mảng (array) | Danh sách user IDs mà người dùng này đã chặn |
| blockedAt_{userId} | dấu thời gian (timestamp) | Thời điểm chặn từng người dùng (field động với userId cụ thể) |
| blockedBy | mảng (array) | Danh sách user IDs đã chặn người dùng này |
| blockedByAt_{userId} | dấu thời gian (timestamp) | Thời điểm bị chặn bởi từng người dùng (field động) |

**Lưu ý:** Collection này quản lý hai chiều: người mà user đã chặn (blocked) và người đã chặn user (blockedBy). Khi user A chặn user B, cả hai document sẽ được cập nhật tương ứng.

---

### **Bảng 1.30: Bộ sưu tập từ ngữ nhạy cảm (sensitiveWords)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| word | chuỗi (string) | Từ ngữ nhạy cảm cần kiểm duyệt (lưu ở dạng chữ thường - lowercase) |
| createdAt | dấu thời gian (timestamp) | Thời điểm thêm từ ngữ vào danh sách |

**Lưu ý:** Collection này phục vụ hệ thống kiểm duyệt nội dung tự động, lọc và cảnh báo các bài viết, bình luận chứa từ ngữ không phù hợp trong mạng xã hội.

---

### **Bảng 1.31: Bộ sưu tập sở thích người dùng (UserFav)**

| Trường (field) | Thuộc tính | Mô tả |
|----------------|------------|-------|
| userId | chuỗi (string) | ID người dùng |
| petId | chuỗi (string) | ID thú cưng yêu thích |
| category | chuỗi (string) | Danh mục thú cưng |
| breed | chuỗi (string) | Giống thú cưng |
| timestamp | dấu thời gian (timestamp) | Thời điểm đánh dấu yêu thích |

**Lưu ý:** Collection này khác với `Favorites`. `UserFav` được sử dụng riêng để phân tích sở thích người dùng, phục vụ thuật toán gợi ý tìm kiếm và đề xuất thú cưng phù hợp. Trong khi `Favorites` lưu danh sách yêu thích đầy đủ để hiển thị trong giao diện người dùng.

---

## Tổng Kết

Dự án **HappyPetStore** sử dụng tổng cộng **22 collections chính** trong Firestore Database:

- **11 collections cơ bản**: Users, Pets, Category, Orders, Notifications, Favorites, Conversations, Carts, ViewedPets, ShopInfo, SearchHistory
- **11 collections bổ sung**: ordersWeb, Breed, chatConversations, groupConversations, socialPosts, socialPetProfiles, socialFollows, socialSettings, blockedUsers, sensitiveWords, UserFav

Các collection bổ sung chủ yếu phục vụ:
- **Tính năng mạng xã hội** (social features): socialPosts, socialPetProfiles, socialFollows, socialSettings, blockedUsers
- **Chat nâng cao** (advanced chat): chatConversations, groupConversations
- **Quản trị web** (web admin): ordersWeb, sensitiveWords
- **Tối ưu hóa** (optimization): Breed, UserFav

---

**Ngày tạo:** 30/11/2025  
**Phiên bản:** 1.0  
**Dự án:** HappyPetStore - Ứng dụng mua bán và nhận nuôi thú cưng
