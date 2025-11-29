import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/services/user_manager.dart';
import '../../../../core/services/community_group_service.dart';
import '../../../bloc/chat/chat_bloc.dart';
import '../../../bloc/chat/chat_event.dart';
import '../../../bloc/chat/chat_state.dart';
import '../../../bloc/group_chat/group_chat_bloc.dart';
import '../../../bloc/group_chat/group_chat_event.dart';
import '../../../bloc/group_chat/group_chat_state.dart';

class ChatListPageWithTabs extends StatefulWidget {
  const ChatListPageWithTabs({super.key});

  @override
  State<ChatListPageWithTabs> createState() => _ChatListPageWithTabsState();
}

class _ChatListPageWithTabsState extends State<ChatListPageWithTabs> 
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = UserManager().currentUserId ?? '';
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload khi app quay lại từ background
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _loadData() {
    if (mounted) {
      context.read<ChatBloc>().add(LoadConversations(_currentUserId));
      context.read<GroupChatBloc>().add(const LoadPublicGroups());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.messages, style: const TextStyle(color: Color(0xFF00A86B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00A86B)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00A86B),
              indicatorWeight: 3,
              labelColor: const Color(0xFF00A86B),
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
              tabs: [
                Tab(
                  icon: const Icon(Icons.person, size: 22),
                  text: l10n.friends,
                ),
                Tab(
                  icon: const Icon(Icons.groups, size: 22),
                  text: l10n.community,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(context, l10n, theme),
          _buildCommunityTab(context, l10n, theme),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return BlocBuilder<ChatBloc, ChatState>(
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
                  onPressed: () => context.read<ChatBloc>().add(LoadConversations(_currentUserId)),
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
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(l10n.noConversationsYet, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ChatBloc>().add(LoadConversations(_currentUserId));
            },
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final otherUserId = conversation.participants.firstWhere((id) => id != _currentUserId);
                final otherUserInfo = conversation.participantsInfo[otherUserId];
                final otherUserName = otherUserInfo?['name'] ?? l10n.unknown;
                final otherUserAvatar = otherUserInfo?['avatarUrl'] ?? '';
                final unreadCount = conversation.unreadCount[_currentUserId] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
                      backgroundImage: otherUserAvatar.isNotEmpty ? NetworkImage(otherUserAvatar) : null,
                      child: otherUserAvatar.isEmpty ? const Icon(Icons.person, color: Color(0xFF00A86B), size: 28) : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        conversation.lastMessage ?? l10n.noMessagesYet,
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Text(
                      _formatTimestamp(conversation.lastMessageTime),
                      style: TextStyle(
                        fontSize: 12, 
                        color: unreadCount > 0 ? const Color(0xFF00A86B) : Colors.grey[500],
                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
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
                  ),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCommunityTab(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return BlocBuilder<GroupChatBloc, GroupChatState>(
      builder: (context, state) {
        if (state is GroupChatLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is GroupChatError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<GroupChatBloc>().add(LoadGroupConversations(_currentUserId)),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          );
        }

        if (state is GroupChatLoaded) {
          final publicGroups = state.publicGroups;

          if (publicGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_outlined, size: 64, color: Color(0xFF00A86B)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.noGroupsYet,
                    style: const TextStyle(fontSize: 18, color: Color(0xFF00A86B), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      l10n.waitForAdminCreateGroup,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<GroupChatBloc>().add(const LoadPublicGroups());
            },
            child: ListView.builder(
              itemCount: publicGroups.length,
              itemBuilder: (context, index) {
                final group = publicGroups[index];
                final isJoined = group.participants.contains(_currentUserId);
                final unreadCount = group.unreadCount[_currentUserId] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
                      backgroundImage: group.avatarUrl != null && group.avatarUrl!.isNotEmpty
                          ? NetworkImage(group.avatarUrl!)
                          : null,
                      child: group.avatarUrl == null || group.avatarUrl!.isEmpty
                          ? const Icon(Icons.group, color: Color(0xFF00A86B), size: 28)
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.isPublic)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.public, size: 10, color: Color(0xFF00A86B)),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.publicGroup,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF00A86B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 4),
                        if (!isJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00A86B).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.joinGroup,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        else if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${group.participants.length} ${l10n.members}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              group.lastMessage ?? l10n.noMessagesYet,
                              style: TextStyle(
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      _formatTimestamp(group.lastMessageTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF00A86B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      if (isJoined) {
                        Navigator.pushNamed(
                          context,
                          '/social/chat/group',
                          arguments: {
                            'groupId': group.id,
                            'groupName': group.name,
                            'groupAvatar': group.avatarUrl,
                          },
                        );
                      } else {
                        _showJoinGroupDialog(context, group.id, group.name);
                      }
                    },
                  ),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showJoinGroupDialog(BuildContext context, String groupId, String groupName) async {
    final l10n = AppLocalizations.of(context)!;
    final service = CommunityGroupService();
    
    if (context.mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Bắt buộc phải chọn
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.group, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.joinGroup)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.doYouWantToJoin} "$groupName"?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn cần tham gia để xem và gửi tin nhắn trong nhóm',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n.join),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      // Nếu user chọn Cancel hoặc bấm ra ngoài -> không làm gì (tự động thoát)
      if (result != true) return;

      // User chọn Join -> thực hiện join
      if (context.mounted) {
        // Hiển thị loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        // Join nhóm
        final success = await service.joinGroup(groupId, _currentUserId);

        // Đóng loading
        if (context.mounted) {
          Navigator.pop(context);
        }

        if (success) {
          // Reload danh sách nhóm
          if (context.mounted) {
            context.read<GroupChatBloc>().add(const LoadPublicGroups());
            
            // Hiển thị thông báo thành công
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.joinedGroup),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );

            // Tự động vào nhóm sau khi join thành công
            await Future.delayed(const Duration(milliseconds: 500));
            if (context.mounted) {
              Navigator.pushNamed(
                context,
                '/social/chat/group',
                arguments: {
                  'groupId': groupId,
                  'groupName': groupName,
                  'groupAvatar': null,
                },
              );
            }
          }
        } else {
          // Join thất bại
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.error),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }
}
