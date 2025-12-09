import 'package:flutter/material.dart';


class MessageRow extends StatelessWidget {
  final bool isMe;
  final String avatarUrl;
  final String text;
  final String time;

  const MessageRow({super.key,
    required this.isMe,
    required this.avatarUrl,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe 
        ? Theme.of(context)
                                    .colorScheme.primary 
        : Theme.of(context).cardColor;
    final textColor = isMe 
        ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white)
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              onBackgroundImageError: avatarUrl.isNotEmpty ? (_, __) {} : null,
              child:
              avatarUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
          ],
          // bubble + time
          Flexible(
            child: Column(
              crossAxisAlignment: align,
              children: [
                Container(
                  constraints: BoxConstraints(
                    // giới hạn độ rộng bubble ~ 70% màn hình
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      if (!isMe)
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withOpacity(.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: SelectableText(
                    text,
                    style: TextStyle(color: textColor, height: 1.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style:
                  TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.surface,
              backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child:
              avatarUrl.isEmpty ? const Icon(Icons.store, size: 16) : null,
              onBackgroundImageError: (_, __) {},
            ),
          ],
        ],
      ),
    );
  }
}