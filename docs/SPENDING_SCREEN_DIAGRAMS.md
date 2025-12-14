# Spending Screen - Sơ đồ hoạt động

## 1. 📋 Sơ đồ tuần tự (Sequence Diagram)

```mermaid
sequenceDiagram
    participant User as Người dùng
    participant UI as Giao diện Chi tiêu
    participant BLoC as SpendingBloc
    participant FireStore as Firestore
    participant OrderScreen as Màn hình Đơn hàng/Đặt chỗ

    User->>UI: Mở màn hình
    UI->>BLoC: Tải dữ liệu (userId, period='month')
    BLoC->>FireStore: Lấy danh sách đơn hàng
    FireStore-->>BLoC: Danh sách đơn hàng

    BLoC->>BLoC: Nhóm theo khoảng thời gian
    BLoC->>BLoC: Tính tổng chi tiêu
    BLoC-->>UI: Trả về dữ liệu
    UI-->>User: Hiển thị biểu đồ chi tiêu

    alt [Chuyển tab thời gian]
        User->>UI: Chọn tab (Tuần/Tháng/Năm)
        UI->>BLoC: Tải dữ liệu với khoảng thời gian mới
        BLoC->>FireStore: Lấy danh sách theo khoảng mới
        FireStore-->>BLoC: Danh sách đơn hàng
        BLoC-->>UI: Trả về dữ liệu
        UI-->>User: Hiển thị biểu đồ mới
    else [Xem chi tiết khoảng thời gian]
        User->>UI: Chạm vào cột biểu đồ
        UI-->>User: Hiển thị danh sách đơn hàng
    else [Mở chi tiết đơn hàng]
        User->>UI: Chạm vào đơn hàng
        UI->>FireStore: Kiểm tra loại đơn hàng
        FireStore-->>UI: Thông tin loại đơn
        UI->>OrderScreen: Chuyển đến màn hình tương ứng
        OrderScreen-->>User: Hiển thị chi tiết đơn hàng
    end

    UI-->>User: Làm mới hiển thị
```

---

## 2. 🔄 Sơ đồ hoạt động (Activity Diagram)

```mermaid
flowchart TD
    Start([Người dùng mở Spending Screen]) --> Init[Khởi tạo TabController<br/>Default: Month tab]
    
    Init --> LoadData[SpendingBloc.LoadSpending<br/>userId, period='month']
    
    LoadData --> QueryOrders[Query Firestore:<br/>orders collection<br/>where userId = currentUser]
    
    QueryOrders --> ProcessData{Có dữ liệu?}
    
    ProcessData -->|Không| ShowEmpty[Hiển thị<br/>'Chưa có dữ liệu chi tiêu']
    ProcessData -->|Có| GroupData[Group orders theo period:<br/>- Week: Mon-Sun<br/>- Month: T1-T4 tuần<br/>- Year: T1-T12 tháng]
    
    GroupData --> CalcTotal[Tính tổng amount<br/>cho mỗi nhóm]
    
    CalcTotal --> RenderChart[Render BarChart với:<br/>- X axis: period keys<br/>- Y axis: totalAmount<br/>- Color: primary color]
    
    RenderChart --> DisplayTotal[Hiển thị Total Card:<br/>Tổng chi tuần/tháng/năm]
    
    DisplayTotal --> WaitInteraction{Đợi user tương tác}
    
    WaitInteraction -->|Chuyển tab| ChangeTab[Thay đổi period:<br/>week/month/year]
    ChangeTab --> LoadData
    
    WaitInteraction -->|Tap cột chart| ShowDetails[Hiển thị Bottom Sheet<br/>với danh sách orders<br/>trong period đó]
    
    ShowDetails --> ListOrders[Hiển thị cards:<br/>- Order ID<br/>- Timestamp<br/>- Pet names + images<br/>- Amount]
    
    ListOrders --> WaitOrderTap{User tap order?}
    
    WaitOrderTap -->|Không| WaitInteraction
    WaitOrderTap -->|Có| CheckType[Query Firestore:<br/>Check reservations<br/>collection]
    
    CheckType --> IsReservation{Document exists<br/>in reservations?}
    
    IsReservation -->|Có| NavReservation[Navigate to<br/>MyReservationsScreen<br/>với reservationId]
    IsReservation -->|Không| NavOrder[Navigate to<br/>YourOrderScreen<br/>với orderId]
    
    NavReservation --> ShowOrderDetail[Hiển thị chi tiết<br/>đơn hàng/đặt chỗ]
    NavOrder --> ShowOrderDetail
    
    ShowOrderDetail --> End([Kết thúc])
    ShowEmpty --> WaitInteraction

    style Start fill:#e1f5e1
    style End fill:#ffe1e1
    style ProcessData fill:#fff4e1
    style IsReservation fill:#fff4e1
    style WaitInteraction fill:#e1f0ff
    style WaitOrderTap fill:#e1f0ff
```

---

## 3. 🏗️ Sơ đồ kiến trúc (Architecture Diagram)

```mermaid
graph TB
    subgraph "UI Layer"
        Screen[SpendingScreen<br/>StatefulWidget]
        Chart[BarChart<br/>fl_chart]
        Card[Total Spending Card]
        Sheet[Period Details<br/>Bottom Sheet]
        OrderCard[Order Card List]
    end

    subgraph "BLoC Layer"
        Bloc[SpendingBloc]
        Event[SpendingEvent:<br/>- LoadSpending]
        State[SpendingState:<br/>- SpendingLoading<br/>- SpendingLoaded<br/>- SpendingError]
    end

    subgraph "Data Layer"
        Firestore[(Firestore)]
        Orders[orders collection]
        Reservations[reservations collection]
    end

    subgraph "Navigation"
        OrderScreen[YourOrderScreen]
        ReservationScreen[MyReservationsScreen]
    end

    Screen -->|dispatch event| Event
    Event -->|handle| Bloc
    Bloc -->|query| Orders
    Bloc -->|emit state| State
    State -->|update| Screen
    
    Screen -->|render| Chart
    Screen -->|render| Card
    Screen -->|show| Sheet
    Sheet -->|display| OrderCard
    
    OrderCard -->|check type| Reservations
    OrderCard -->|navigate| OrderScreen
    OrderCard -->|navigate| ReservationScreen

    style Screen fill:#4a90e2,color:#fff
    style Bloc fill:#50c878,color:#fff
    style Firestore fill:#ffa500,color:#fff
```

---

## 4. 📊 Data Flow Diagram

```mermaid
flowchart LR
    subgraph Input
        UserId[User ID]
        Period[Period<br/>week/month/year]
    end

    subgraph Processing
        Query[Firestore Query:<br/>orders where<br/>userId = input]
        Group[Group by Period:<br/>- Week: Mon-Sun<br/>- Month: Week 1-4<br/>- Year: Month 1-12]
        Calc[Calculate:<br/>totalAmount<br/>per group]
    end

    subgraph Output
        ChartData[BarChart Data:<br/>x: period keys<br/>y: amounts]
        Total[Total Amount<br/>Display]
        DetailList[Order Details List]
    end

    UserId --> Query
    Period --> Query
    Query --> Group
    Group --> Calc
    Calc --> ChartData
    Calc --> Total
    ChartData --> DetailList

    style Query fill:#e3f2fd
    style Group fill:#fff3e0
    style Calc fill:#f3e5f5
    style ChartData fill:#e8f5e9
```

---

## 5. 🔍 Chi tiết các thành phần

### **5.1. TabController Logic**
```dart
TabIndex 0 → period = 'week'
TabIndex 1 → period = 'month' (default)
TabIndex 2 → period = 'year'

_onTabChanged() → detect tab change → dispatch LoadSpending
```

### **5.2. Data Grouping Logic**
- **Week**: Group theo ngày trong tuần (Mon, Tue, Wed,...)
- **Month**: Group theo tuần trong tháng (T1, T2, T3, T4)
- **Year**: Group theo tháng trong năm (T1-T12)

### **5.3. Chart Touch Interaction**
```
FlTapUpEvent → get touchedBarGroupIndex 
→ find periodKey from sortedKeys[index]
→ call _showPeriodDetails(periodKey, data)
```

### **5.4. Order Type Detection**
```
Tap Order Card 
→ Query reservations/{orderId}
→ If exists: Navigate to MyReservationsScreen
→ Else: Navigate to YourOrderScreen
```

---

## 6. 🎯 User Journey

```mermaid
journey
    title User Journey - Spending Screen
    section Xem tổng quan
      Mở màn hình: 5: User
      Xem biểu đồ tháng: 5: User
      Xem tổng chi tiêu: 4: User
    section Phân tích chi tiết
      Chuyển sang tab tuần: 4: User
      So sánh các tuần: 3: User
      Tap vào cột cao nhất: 5: User
    section Xem chi tiết đơn
      Xem danh sách orders: 5: User
      Tap vào order cụ thể: 5: User
      Xem chi tiết pet đã mua: 5: User
    section Theo dõi xu hướng
      Chuyển sang tab năm: 4: User
      Nhận biết tháng chi nhiều: 5: User
      Lập kế hoạch chi tiêu: 3: User
```

---

## 7. ⚡ Performance Considerations

### **Optimizations:**
1. **BLoC Caching**: State được giữ khi chuyển tab nếu period không đổi
2. **Lazy Loading**: Bottom sheet chỉ load khi user tap vào cột
3. **Image Caching**: NetworkImage tự cache pet images
4. **Query Optimization**: Index trên `userId` và `timestamp` trong Firestore

### **Potential Issues:**
1. **Large Dataset**: Nếu user có nhiều orders, chart có thể lag
2. **Network Latency**: Mỗi lần chuyển tab query lại Firestore
3. **Memory**: Giữ tất cả order data trong memory

---

## 8. 🔒 Security & Privacy

- **Data Access**: Chỉ query orders của chính user (userId filter)
- **No Sensitive Data**: Không lưu thông tin thanh toán trong chart
- **Firestore Rules**: Cần rule để chỉ user được xem orders của mình

---

## 9. 📱 UI/UX Features

### **Tính năng tốt:**
✅ Tab navigation rõ ràng (Week/Month/Year)  
✅ Total card nổi bật với icon và format currency  
✅ Interactive chart với tooltip  
✅ Bottom sheet mượt mà với DraggableScrollableSheet  
✅ Pet images trong order list  
✅ Auto-detect order vs reservation  

### **Có thể cải thiện:**
❓ Thêm filter theo status (Pending/Completed)  
❓ Export data to CSV/PDF  
❓ Compare với period trước  
❓ Notifications khi chi tiêu vượt ngưỡng  
❓ Spending goals/budgets  

---

## 10. 🧪 Test Scenarios

```gherkin
Feature: Spending Analytics

  Scenario: Xem chi tiêu theo tháng
    Given User đã đăng nhập
    When User mở Spending Screen
    Then Hiển thị tab "Theo tháng" active
    And Hiển thị biểu đồ 4 tuần
    And Hiển thị tổng chi tháng này

  Scenario: Chuyển sang xem theo năm
    Given User đang ở tab tháng
    When User tap vào tab "Theo năm"
    Then Hiển thị biểu đồ 12 tháng
    And Hiển thị tổng chi năm này

  Scenario: Xem chi tiết một khoảng thời gian
    Given Biểu đồ đang hiển thị
    When User tap vào cột "Tuần 2"
    Then Hiển thị bottom sheet
    And Liệt kê tất cả orders trong tuần 2
    And Hiển thị pet images và amounts

  Scenario: Mở chi tiết order
    Given Bottom sheet đang hiển thị orders
    When User tap vào một order card
    Then System check order type
    And Navigate đến YourOrderScreen hoặc MyReservationsScreen
```

---

## 📌 Tổng kết

Chức năng **Spending Screen** sử dụng:

1. **Sơ đồ tuần tự (Sequence)** → Mô tả tương tác giữa User, UI, BLoC, Firestore
2. **Sơ đồ hoạt động (Activity)** → Mô tả logic flow và decision points
3. **Sơ đồ kiến trúc** → Mô tả cấu trúc layers (UI, BLoC, Data)
4. **Data Flow** → Mô tả luồng dữ liệu từ input đến output

**Cả 4 sơ đồ đều cần thiết** để hiểu toàn diện chức năng này! 🎯
