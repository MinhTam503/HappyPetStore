import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_bloc.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_event.dart';
import 'package:pet_shop/presentation/bloc/notification/notification_state.dart';
import 'package:pet_shop/presentation/pages/mobile/notification/nofi_screen.dart';

class NotificationButton extends StatefulWidget {
  final String userId;
  const NotificationButton({super.key, required this.userId});

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationBloc>().add(LoadUnreadCount(widget.userId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kích thước thật sẽ do SizedBox.square(dimension: 28) ở parent khống chế
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        radius: 18,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NofiScreen(userId: widget.userId)),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 28, color: Colors.black87),

            BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                int unread = 0;
                if (state is NotificationListening) unread = state.unreadCount;
                else if (state is NotificationLoaded) unread = state.unreadCount;
                else if (state is UnreadCountLoaded) unread = state.count;

                if (unread <= 0) return const SizedBox.shrink();

                return Positioned(
                  // hơi lệch ra ngoài để badge không đẩy icon xuống
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
