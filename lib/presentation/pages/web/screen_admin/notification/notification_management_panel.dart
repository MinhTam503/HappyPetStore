import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pet_shop/helpers/order_notification_helper.dart';
import 'package:pet_shop/core/utils/dialog_helper.dart';

class NotificationManagementPanel extends StatefulWidget {
  const NotificationManagementPanel({super.key});

  @override
  State<NotificationManagementPanel> createState() =>
      _NotificationManagementPanelState();
}

class _NotificationManagementPanelState
    extends State<NotificationManagementPanel>
    with SingleTickerProviderStateMixin {
  int selectedTabIndex = 0;
  TabController? _tabController;

  final Map<String, dynamic> _notificationStats = {};
  final List<Map<String, dynamic>> _usersWithUnread = [];
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(_onTabChanged);
    _loadNotificationAnalytics();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController!.indexIsChanging) {
      setState(() {
        selectedTabIndex = _tabController!.index;
      });

      // Refresh data when switching to analytics tab
      if (selectedTabIndex == 0) {
        _loadNotificationAnalytics();
      }
    }
  }

  Future<void> _loadNotificationAnalytics() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await OrderNotificationHelper.getNotificationAnalytics();
      final usersWithUnread =
          await OrderNotificationHelper.getUsersWithMostUnreadNotifications();

      setState(() {
        _notificationStats.clear();
        _notificationStats.addAll(stats);
        _usersWithUnread.clear();
        _usersWithUnread.addAll(usersWithUnread);
      });
    } catch (e) {
      print('Error loading notification analytics: $e');
    } finally {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.notification),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.analytics), text: 'Thống kê'),
              // Tab(icon: Icon(Icons.campaign), text: 'Khuyến mãi'),
              Tab(icon: Icon(Icons.notifications), text: 'Thông báo chung'),
              // Tab(icon: Icon(Icons.schedule), text: 'Lịch hẹn'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAnalyticsTab(),
            // _buildPromotionTab(),
            _buildGeneralNotificationTab(),
            // _buildAppointmentTab(),
          ],
        ),
      ),
    );
  }

  // ===================== ANALYTICS TAB =====================
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Tổng thông báo',
                  _notificationStats['total']?.toString() ?? '0',
                  Icons.notifications,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Chưa đọc',
                  _notificationStats['unread']?.toString() ?? '0',
                  Icons.mark_email_unread,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Đã đọc',
                  _notificationStats['read']?.toString() ?? '0',
                  Icons.mark_email_read,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Refresh Button
          ElevatedButton.icon(
            onPressed: _isLoadingStats ? null : _loadNotificationAnalytics,
            icon: _isLoadingStats
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Làm mới thống kê'),
          ),

          const SizedBox(height: 24),

          // Type Statistics
          if (_notificationStats['typeStats'] != null) ...[
            const Text(
              'Thống kê theo loại thông báo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._buildTypeStatsList(),
          ],

          const SizedBox(height: 24),

          // Users with most unread
          const Text(
            'Users có nhiều thông báo chưa đọc',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._buildUsersWithUnreadList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeStatsList() {
    final typeStats =
        _notificationStats['typeStats'] as Map<String, dynamic>? ?? {};

    return typeStats.entries.map((entry) {
      final type = entry.key;
      final count = entry.value;

      String displayName;
      IconData iconData;
      Color color;

      switch (type) {
        case 'orderPlaced':
          displayName = 'Đơn hàng mới';
          iconData = Icons.shopping_cart;
          color = Colors.blue;
          break;
        case 'orderConfirmed':
          displayName = 'Đơn hàng xác nhận';
          iconData = Icons.check_circle;
          color = Colors.green;
          break;
        case 'orderCancelled':
          displayName = 'Đơn hàng hủy';
          iconData = Icons.cancel;
          color = Colors.red;
          break;
        case 'orderShipped':
          displayName = 'Đơn hàng giao';
          iconData = Icons.local_shipping;
          color = Colors.orange;
          break;
        case 'orderDelivered':
          displayName = 'Đơn hàng hoàn thành';
          iconData = Icons.done_all;
          color = Colors.purple;
          break;
        case 'promotion':
          displayName = 'Khuyến mãi';
          iconData = Icons.local_offer;
          color = Colors.amber;
          break;
        case 'appointment':
          displayName = 'Lịch hẹn';
          iconData = Icons.event;
          color = Colors.cyan;
          break;
        default:
          displayName = 'Khác';
          iconData = Icons.notifications;
          color = Colors.grey;
      }

      return Card(
        child: ListTile(
          leading: Icon(iconData, color: color),
          title: Text(displayName),
          trailing: Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildUsersWithUnreadList() {
    if (_usersWithUnread.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Không có dữ liệu'),
          ),
        ),
      ];
    }

    return _usersWithUnread.map((user) {
      final userId = user['userId']?.toString() ?? '';
      final unreadCount = user['unreadCount']?.toString() ?? '0';

      return Card(
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text('User ID: $userId'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unreadCount,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ===================== PROMOTION TAB =====================
  Widget _buildPromotionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Send promotion to all users
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gửi khuyến mãi cho tất cả khách hàng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showPromotionDialog(isVIPOnly: false),
                    icon: const Icon(Icons.campaign),
                    label: const Text('Tạo khuyến mãi'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Send promotion to VIP users
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gửi khuyến mãi cho khách hàng VIP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khách hàng VIP là những người đã đặt từ 5 đơn hàng trở lên',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showPromotionDialog(isVIPOnly: true),
                    icon: const Icon(Icons.star),
                    label: const Text('Tạo khuyến mãi VIP'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPromotionDialog({required bool isVIPOnly}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final promoCodeController = TextEditingController();
    final discountController = TextEditingController();
    DateTime? expiryDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              isVIPOnly ? 'Tạo khuyến mãi VIP' : 'Tạo khuyến mãi cho tất cả'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promoCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã khuyến mãi (tùy chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: discountController,
                  decoration: const InputDecoration(
                    labelText: 'Phần trăm giảm giá (tùy chọn)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expiryDate != null
                            ? 'Hết hạn: ${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}'
                            : 'Không có hạn sử dụng',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            expiryDate = date;
                          });
                        }
                      },
                      child: const Text('Chọn ngày'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    contentController.text.isEmpty) {
                  return;
                }

                Navigator.pop(context);

                // Show DialogHelper loading
                DialogHelper.showLoadingDialog(context,
                    message: 'Đang gửi khuyến mãi...');

                try {
                  final discountValue =
                      double.tryParse(discountController.text);

                  if (isVIPOnly) {
                    await OrderNotificationHelper.sendPromotionToVIPCustomers(
                      title: titleController.text,
                      content: contentController.text,
                      promoCode: promoCodeController.text.isEmpty
                          ? null
                          : promoCodeController.text,
                      discountPercentage: discountValue,
                      expiryDate: expiryDate,
                    );
                  } else {
                    await OrderNotificationHelper.sendPromotionToAllCustomers(
                      title: titleController.text,
                      content: contentController.text,
                      promoCode: promoCodeController.text.isEmpty
                          ? null
                          : promoCodeController.text,
                      discountPercentage: discountValue,
                      expiryDate: expiryDate,
                    );
                  }

                  if (!mounted) return;
                  DialogHelper.hideLoadingDialog(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Khuyến mãi đã được gửi thành công!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Refresh analytics after successful send
                  _loadNotificationAnalytics();
                } catch (e) {
                  if (!mounted) return;
                  DialogHelper.hideLoadingDialog(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi gửi khuyến mãi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== GENERAL NOTIFICATION TAB =====================
  Widget _buildGeneralNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gửi thông báo chung',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gửi thông báo tới tất cả người dùng trong hệ thống',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showGeneralNotificationDialog,
                    icon: const Icon(Icons.notifications),
                    label: const Text('Tạo thông báo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGeneralNotificationDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo thông báo chung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  contentController.text.isEmpty) {
                return;
              }

              Navigator.pop(context);

              // Show DialogHelper loading
              DialogHelper.showLoadingDialog(context,
                  message: 'Đang gửi thông báo...');

              try {
                await OrderNotificationHelper.sendGeneralNotificationToAll(
                  title: titleController.text,
                  content: contentController.text,
                );

                if (!mounted) return;
                DialogHelper.hideLoadingDialog(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thông báo đã được gửi thành công!'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Refresh analytics after successful send
                _loadNotificationAnalytics();
              } catch (e) {
                if (!mounted) return;
                DialogHelper.hideLoadingDialog(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi gửi thông báo: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  // ===================== APPOINTMENT TAB =====================
  Widget _buildAppointmentTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quản lý thông báo lịch hẹn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tính năng này sẽ được phát triển trong tương lai để quản lý thông báo lịch hẹn khám thú cưng.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
