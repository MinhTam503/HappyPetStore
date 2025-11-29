import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/services/user_manager.dart';
import '../../../../bloc/group_chat/group_chat_bloc.dart';
import '../../../../bloc/group_chat/group_chat_event.dart';
import '../../../../bloc/group_chat/group_chat_state.dart';
import '../../../../../domain/entities/group_chat_entities.dart';
import 'group_info_page.dart';

class GroupChatRoomPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;

  const GroupChatRoomPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
  });

  @override
  State<GroupChatRoomPage> createState() => _GroupChatRoomPageState();
}

class _GroupChatRoomPageState extends State<GroupChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late String _currentUserId;
  bool _isUploading = false;
  Set<String> _blockedUserIds = {};
  GroupConversation? _groupInfo;
  GroupChatMessage? _replyingTo;
  final Map<String, GroupChatMessage> _messagesCache = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = UserManager().currentUserId ?? '';
    _loadBlockedUsers();
    _loadGroupInfo();
    _loadMessages();
    _markAsRead();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groupConversations')
          .doc(widget.groupId)
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          _groupInfo = GroupConversation(
            id: doc.id,
            name: doc.data()?['name'] ?? '',
            avatarUrl: doc.data()?['avatarUrl'],
            participants: List<String>.from(doc.data()?['participants'] ?? []),
            createdBy: doc.data()?['createdBy'] ?? '',
            isPublic: doc.data()?['isPublic'] ?? false,
            lastMessage: doc.data()?['lastMessage'],
            lastMessageTime: (doc.data()?['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastMessageSenderId: doc.data()?['lastMessageSenderId'],
            createdAt: (doc.data()?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            participantsInfo: Map<String, Map<String, dynamic>>.from(doc.data()?['participantsInfo'] ?? {}),
            admins: List<String>.from(doc.data()?['admins'] ?? []),
            unreadCount: Map<String, int>.from(doc.data()?['unreadCount'] ?? {}),
          );
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading group info: $e');
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(_currentUserId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        
        setState(() {
          _blockedUserIds = {...blocked.cast<String>(), ...blockedBy.cast<String>()};
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading blocked users: $e');
    }
  }

  void _loadMessages() {
    context.read<GroupChatBloc>().add(LoadGroupMessages(widget.groupId));
  }

  void _markAsRead() {
    context.read<GroupChatBloc>().add(MarkGroupMessagesAsRead(
          groupId: widget.groupId,
          userId: _currentUserId,
        ));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyToId = _replyingTo?.id;
    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });
    
    context.read<GroupChatBloc>().add(SendGroupMessage(
          groupId: widget.groupId,
          senderId: _currentUserId,
          text: text,
          replyToId: replyToId,
        ));

    // Scroll to bottom (minScrollExtent because list is reversed)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_chat_images')
          .child('${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      final replyToId = _replyingTo?.id;
      setState(() {
        _replyingTo = null;
      });
      
      if (mounted) {
        context.read<GroupChatBloc>().add(SendGroupImage(
              groupId: widget.groupId,
              senderId: _currentUserId,
              imageUrl: imageUrl,
              replyToId: replyToId,
            ));
      }

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorUploadingImage}: $e')),
        );
      }
    }
  }

  void _setReplyingTo(GroupChatMessage? message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _showMessageOptions(BuildContext context, GroupChatMessage message, AppLocalizations l10n) {
    if (message.isSystemMessage) return; // No menu for system messages
    
    final isMe = message.senderId == _currentUserId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00A86B)),
              title: Text(l10n.reply),
              onTap: () {
                Navigator.pop(context);
                _setReplyingTo(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined, color: Colors.amber),
              title: Text(l10n.addReaction),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.deleteMessage),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(context, message, l10n);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, GroupChatMessage message) {
    final emojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.addReaction,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.read<GroupChatBloc>().add(AddGroupReaction(
                            groupId: widget.groupId,
                            messageId: message.id,
                            userId: _currentUserId,
                            emoji: emoji,
                          ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMessage(BuildContext context, GroupChatMessage message, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessage),
        content: Text(l10n.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GroupChatBloc>().add(DeleteGroupMessage(
                    groupId: widget.groupId,
                    messageId: message.id,
                  ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.messageDeleted)),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF00A86B)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00A86B)),
          onPressed: () {
            // Reload public groups trước khi back
            context.read<GroupChatBloc>().add(const LoadPublicGroups());
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
              backgroundImage: widget.groupAvatar != null && widget.groupAvatar!.isNotEmpty
                  ? NetworkImage(widget.groupAvatar!)
                  : null,
              child: widget.groupAvatar == null || widget.groupAvatar!.isEmpty
                  ? const Icon(Icons.group, color: Color(0xFF00A86B), size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.87),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_groupInfo != null)
                    Text(
                      '${_groupInfo!.participants.length} thành viên',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF00A86B)),
            onPressed: () {
              if (_groupInfo != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfoPage(
                      groupInfo: _groupInfo!,
                      currentUserId: _currentUserId,
                      onLeaveGroup: () {
                        Navigator.pop(context); // Đóng group info
                        _showLeaveGroupDialog();
                      },
                    ),
                  ),
                );
              }
            },
            tooltip: 'Thông tin nhóm',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<GroupChatBloc, GroupChatState>(
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
                          onPressed: _loadMessages,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (state is GroupChatLoaded) {
                  // Filter messages: show system messages and hide messages from blocked users
                  final messages = state.messages
                      .where((msg) => msg.isSystemMessage || !_blockedUserIds.contains(msg.senderId))
                      .toList();

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.sendFirstMessage,
                            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final isMe = message.senderId == _currentUserId;

                      // Cache messages for reply lookup
                      if (!message.isSystemMessage) {
                        _messagesCache[message.id] = message;
                      }

                      return GestureDetector(
                        onLongPress: message.isSystemMessage 
                            ? null 
                            : () => _showMessageOptions(context, message, l10n),
                        child: _buildMessageBubble(message, isMe, theme, l10n, messages),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reply indicator bar
                if (_replyingTo != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B).withOpacity(0.1),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFF00A86B),
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.replyTo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A86B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _replyingTo!.text ?? '📷 Photo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _setReplyingTo(null),
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),

                // Input row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.image),
                        onPressed: _isUploading ? null : _pickAndSendImage,
                        color: theme.colorScheme.primary,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: l10n.typeMessage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        child: IconButton(
                          icon: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    GroupChatMessage message,
    bool isMe,
    ThemeData theme,
    AppLocalizations l10n,
    List<GroupChatMessage> allMessages,
  ) {
    // System messages (join/leave notifications) - centered, no avatar
    if (message.isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Get replied message if exists
    GroupChatMessage? repliedMessage;
    if (message.replyToId != null) {
      repliedMessage = _messagesCache[message.replyToId];
    }

    // Get reactions
    final reactions = message.reactions;
    final hasReactions = reactions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (only for other users)
          if (!isMe) ...[
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('socialPetProfiles')
                  .doc(message.senderId)
                  .get(),
              builder: (context, snapshot) {
                String? avatarUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  avatarUrl = data['avatarUrl'];
                }
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (only for other users)
                if (!isMe)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('socialPetProfiles')
                        .doc(message.senderId)
                        .get(),
                    builder: (context, snapshot) {
                      String senderName = 'User';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        senderName = data['displayName'] ?? data['petName'] ?? 'User';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                
                // Image-only messages (no colored bubble)
                if (message.imageUrl != null && 
                    message.imageUrl!.isNotEmpty && 
                    (message.text == null || message.text!.isEmpty) &&
                    repliedMessage == null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          width: 200,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: 150,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                
                // Messages with text (or replied message) - show in colored bubble
                if (message.text != null && message.text!.isNotEmpty ||
                    repliedMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF00A86B) : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Replied message indicator
                      if (repliedMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.2) : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isMe ? Colors.white : const Color(0xFF00A86B),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repliedMessage.senderId == _currentUserId
                                    ? l10n.you
                                    : 'Member',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Theme.of(context).colorScheme.onPrimary : const Color(0xFF00A86B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                repliedMessage.text ?? '📷 Photo',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Image if present (and has text or reply)
                      if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                width: 200,
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 150,
                                width: 150,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error, color: Colors.red),
                              );
                            },
                          ),
                        ),
                      
                      // Text if present
                      if (message.text != null && message.text!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: (message.imageUrl?.isNotEmpty ?? false) ? 8 : 0,
                          ),
                          child: Text(
                            message.text!,
                            style: TextStyle(
                              color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Reactions
                if (hasReactions)
                  Container(
                    margin: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(entry.value, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                    ),
                  ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog() {
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final groupChatBloc = context.read<GroupChatBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.leaveGroup),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn rời khỏi nhóm "${widget.groupName}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn có thể tham gia lại bất kỳ lúc nào',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Đóng dialog
              
              // Hiển thị loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Leave group
                await FirebaseFirestore.instance
                    .collection('groupConversations')
                    .doc(widget.groupId)
                    .update({
                  'participants': FieldValue.arrayRemove([_currentUserId]),
                  'participantsInfo.$_currentUserId': FieldValue.delete(),
                  'unreadCount.$_currentUserId': FieldValue.delete(),
                });

                // Thêm system message
                await FirebaseFirestore.instance
                    .collection('groupConversations')
                    .doc(widget.groupId)
                    .collection('messages')
                    .add({
                  'senderId': _currentUserId,
                  'text': '${_groupInfo?.participantsInfo[_currentUserId]?['name'] ?? 'User'} đã rời khỏi nhóm',
                  'timestamp': FieldValue.serverTimestamp(),
                  'readBy': {},
                  'isSystemMessage': true,
                });

                // Đóng loading
                navigator.pop();
                
                // Reload public groups before back
                groupChatBloc.add(const LoadPublicGroups());
                
                // Back về chat list
                navigator.pop();
                
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 8),
                        Text(l10n.leftGroup),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Đóng loading
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 8),
                        Text(l10n.error),
                      ],
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(l10n.leaveGroup),
          ),
        ],
      ),
    );
  }
}
