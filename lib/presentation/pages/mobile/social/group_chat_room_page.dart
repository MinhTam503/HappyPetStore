import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/user_manager.dart';
import '../../../bloc/group_chat/group_chat_bloc.dart';
import '../../../bloc/group_chat/group_chat_event.dart';
import '../../../bloc/group_chat/group_chat_state.dart';
import '../../../../domain/entities/group_chat_entities.dart';
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

    _messageController.clear();
    context.read<GroupChatBloc>().add(SendGroupMessage(
          groupId: widget.groupId,
          senderId: _currentUserId,
          text: text,
        ));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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

      if (mounted) {
        context.read<GroupChatBloc>().add(SendGroupImage(
              groupId: widget.groupId,
              senderId: _currentUserId,
              imageUrl: imageUrl,
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
        backgroundColor: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_groupInfo != null)
                    Text(
                      '${_groupInfo!.participants.length} thành viên',
                      style: TextStyle(
                        color: Colors.grey[600],
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
                  // Filter messages from blocked users
                  final messages = state.messages
                      .where((msg) => !_blockedUserIds.contains(msg.senderId))
                      .toList();

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            l10n.sendFirstMessage,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

                      return _buildMessageBubble(message, isMe, theme, l10n);
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
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
                      fillColor: Colors.grey[100],
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
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(GroupChatMessage message, bool isMe, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            // Sender avatar for group messages
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
                  backgroundColor: Colors.grey[300],
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Icon(Icons.person, size: 16, color: Colors.grey[600])
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
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? theme.colorScheme.primary : Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.imageUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (message.text != null && message.text!.isNotEmpty)
                        Text(
                          message.text!,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
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
                        const Icon(Icons.check_circle, color: Colors.white),
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
                        const Icon(Icons.error_outline, color: Colors.white),
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
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.leaveGroup),
          ),
        ],
      ),
    );
  }
}
