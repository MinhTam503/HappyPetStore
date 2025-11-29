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
import '../../../../../domain/entities/chat_entities.dart';
import '../../../../bloc/chat/chat_bloc.dart';
import '../../../../bloc/chat/chat_event.dart';
import '../../../../bloc/chat/chat_state.dart';

class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late String _currentUserId;
  bool _isUploading = false;
  bool _isBlocked = false;
  
  // Reply functionality
  ChatMessage? _replyingTo;
  final Map<String, ChatMessage> _messagesCache = {}; // Cache for quick lookup

  @override
  void initState() {
    super.initState();
    _currentUserId = UserManager().currentUserId ?? '';
    _checkIfBlocked();
    _loadMessages();
    _markAsRead();
  }

  Future<void> _checkIfBlocked() async {
    try {
      final aDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(_currentUserId)
          .get();
      if (aDoc.exists) {
        final data = aDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(widget.otherUserId) ||
            blockedBy.contains(widget.otherUserId)) {
          if (mounted) setState(() => _isBlocked = true);
          return;
        }
      }
      final bDoc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(widget.otherUserId)
          .get();
      if (bDoc.exists) {
        final data = bDoc.data() as Map<String, dynamic>;
        final List<dynamic> blocked = data['blocked'] ?? [];
        final List<dynamic> blockedBy = data['blockedBy'] ?? [];
        if (blocked.contains(_currentUserId) ||
            blockedBy.contains(_currentUserId)) {
          if (mounted) setState(() => _isBlocked = true);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking blocked: $e');
    }
  }

  void _loadMessages() {
    context.read<ChatBloc>().add(LoadMessages(widget.conversationId));
  }

  void _markAsRead() {
    context.read<ChatBloc>().add(MarkMessagesAsRead(
          conversationId: widget.conversationId,
          userId: _currentUserId,
        ));
  }

  Future<void> _sendMessage() async {
    if (_isBlocked) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyToId = _replyingTo?.id;
    
    _messageController.clear();
    _setReplyingTo(null); // Clear reply after sending
    
    context.read<ChatBloc>().add(SendMessage(
          conversationId: widget.conversationId,
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
    if (_isBlocked) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('chat_images').child(
          '${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      if (kDebugMode) {
        print('📸 Image uploaded successfully: $imageUrl');
      }

      final replyToId = _replyingTo?.id;
      _setReplyingTo(null); // Clear reply after sending
      
      // Send image message
      if (mounted) {
        context.read<ChatBloc>().add(SendImageMessage(
              conversationId: widget.conversationId,
              senderId: _currentUserId,
              imageUrl: imageUrl,
              replyToId: replyToId,
            ));
      }

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.errorUploadingImage}: $e')),
        );
      }
    }
  }

  void _setReplyingTo(ChatMessage? message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _showMessageOptions(BuildContext context, ChatMessage message, AppLocalizations l10n) {
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
            // Reply option
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF00A86B)),
              title: Text(l10n.reply),
              onTap: () {
                Navigator.pop(context);
                _setReplyingTo(message);
              },
            ),
            
            // Reaction option
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined, color: Colors.amber),
              title: Text(l10n.addReaction),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, message);
              },
            ),
            
            // Delete option (only for own messages)
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

  void _showReactionPicker(BuildContext context, ChatMessage message) {
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ChatBloc>().add(AddReaction(
                            conversationId: widget.conversationId,
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
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
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

  void _confirmDeleteMessage(BuildContext context, ChatMessage message, AppLocalizations l10n) {
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
              context.read<ChatBloc>().add(DeleteMessage(
                    conversationId: widget.conversationId,
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
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.surface,
              backgroundImage: widget.otherUserAvatar.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar) as ImageProvider
                  : null,
              child: widget.otherUserAvatar.isEmpty
                  ? Icon(Icons.person, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
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
                          onPressed: _loadMessages,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ChatLoaded) {
                  final messages = state.messages;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.sendFirstMessage,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
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
                      // Reverse index because list is reversed
                      final message = messages[messages.length - 1 - index];
                      final isMe = message.senderId == _currentUserId;
                      
                      // Cache messages for reply lookup
                      _messagesCache[message.id] = message;

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(context, message, l10n),
                        child: _buildMessageBubble(message, isMe, theme, l10n, messages),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Blocked banner (like Facebook Messenger)
          if (_isBlocked)
            Container(
              color: theme.colorScheme.surfaceVariant,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.cannotReplyConversation,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          if (!_isBlocked)
            Column(
              children: [
                // Reply indicator
                if (_replyingTo != null)
                  Container(
                    color: theme.colorScheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 40,
                          color: const Color(0xFF00A86B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.reply, size: 16, color: Color(0xFF00A86B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.replyTo,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00A86B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      // Image picker button
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

                      // Text input
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
                            fillColor: Theme.of(context).colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Send button
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        child: IconButton(
                          icon:
                              Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isMe,
    ThemeData theme,
    AppLocalizations l10n,
    List<ChatMessage> allMessages,
  ) {
    // Get replied message if exists
    ChatMessage? repliedMessage;
    if (message.replyToId != null) {
      repliedMessage = _messagesCache[message.replyToId];
    }

    // Get reactions
    final reactions = message.reactions;
    final hasReactions = reactions.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image-only messages (no colored bubble)
            if (message.imageUrl != null && 
                message.imageUrl!.isNotEmpty && 
                (message.text == null || message.text!.isEmpty) &&
                repliedMessage == null)
              GestureDetector(
                onLongPress: () => _showMessageOptions(context, message, l10n),
                child: ClipRRect(
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
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        width: 150,
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(height: 8),
                            Text('Failed to load'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Messages with text (or replied message) - show in colored bubble
            if (message.text != null && message.text!.isNotEmpty ||
                repliedMessage != null)
              GestureDetector(
                onLongPress: () => _showMessageOptions(context, message, l10n),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF00A86B) : Colors.grey[200],
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
                        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
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
                                : widget.otherUserName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : const Color(0xFF00A86B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repliedMessage.text ?? '📷 Photo',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.grey[700],
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
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            width: 150,
                            color: Colors.grey[200],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red),
                                SizedBox(height: 8),
                                Text('Failed to load'),
                              ],
                            ),
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
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
