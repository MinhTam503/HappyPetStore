import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../../core/services/user_manager.dart';
import '../../../../bloc/chat/chat_bloc.dart';
import '../../../../bloc/chat/chat_event.dart';
import '../../../../bloc/chat/chat_state.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = UserManager().currentUserId ?? '';
    _loadConversations();
  }

  void _loadConversations() {
    context.read<ChatBloc>().add(LoadConversations(_currentUserId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messages),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChatError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (state is ChatLoaded) {
            final conversations = state.conversations;

            if (conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noConversationsYet,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                _loadConversations();
              },
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  
                  // Get other user info
                  final otherUserId = conversation.participants
                      .firstWhere((id) => id != _currentUserId);
                  final otherUserInfo = conversation.participantsInfo[otherUserId];
                  final otherUserName = otherUserInfo?['name'] ?? l10n.unknown;
                  final otherUserAvatar = otherUserInfo?['avatarUrl'] ?? '';
                  
                  // Unread count
                  final unreadCount = conversation.unreadCount[_currentUserId] ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: otherUserAvatar.isNotEmpty
                          ? NetworkImage(otherUserAvatar)
                          : null,
                      child: otherUserAvatar.isEmpty
                          ? Icon(Icons.person, color: Colors.grey[600])
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      conversation.lastMessage ?? l10n.noMessagesYet,
                      style: TextStyle(
                        fontWeight: unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatTimestamp(conversation.lastMessageTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/social/chat/room',
                        arguments: {
                          'conversationId': conversation.id,
                          'otherUserId': otherUserId,
                          'otherUserName': otherUserName,
                          'otherUserAvatar': otherUserAvatar,
                        },
                      );
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      // Today: show time
      return DateFormat('HH:mm').format(timestamp);
    } else if (diff.inDays == 1) {
      // Yesterday
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      // This week: show day name
      return DateFormat('EEE').format(timestamp);
    } else {
      // Older: show date
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }
}
