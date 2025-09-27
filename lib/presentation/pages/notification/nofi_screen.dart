import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class NofiScreen extends StatefulWidget {
  const NofiScreen({super.key});

  @override
  State<NofiScreen> createState() => _NofiScreenState();
}

class _NofiScreenState extends State<NofiScreen> {
  final List<NotificationItem> notifications = [
    NotificationItem(
      icon: Icons.local_offer,
      title: 'Ưu đãi đặc biệt!',
      content: 'Giảm 20% cho tất cả các sản phẩm thú cưng trong tuần này',
      time: '1 giờ trước',
      color: Colors.orange,
    ),
    NotificationItem(
      icon: Icons.pets,
      title: 'Dịch vụ mới',
      content: 'Chúng tôi vừa bổ sung thêm dịch vụ spa cho thú cưng',
      time: '2 giờ trước',
      color: primaryColor,
    ),
    NotificationItem(
      icon: Icons.calendar_today,
      title: 'Nhắc nhở',
      content: 'Đến lịch tiêm phòng cho thú cưng của bạn',
      time: '1 ngày trước',
      color: Colors.blue,
    ),
  ];

  void _removeNotification(int index) {
    setState(() {
      notifications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Thông báo",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                notifications.clear();
              });
            },
          ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có thông báo nào',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                return Dismissible(
                  key: Key(notifications[index].title),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _removeNotification(index);
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            notifications[index].color.withOpacity(0.2),
                        child: Icon(
                          notifications[index].icon,
                          color: notifications[index].color,
                        ),
                      ),
                      title: Text(
                        notifications[index].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notifications[index].content),
                          const SizedBox(height: 4),
                          Text(
                            notifications[index].time,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class NotificationItem {
  final IconData icon;
  final String title;
  final String content;
  final String time;
  final Color color;

  NotificationItem({
    required this.icon,
    required this.title,
    required this.content,
    required this.time,
    required this.color,
  });
}
