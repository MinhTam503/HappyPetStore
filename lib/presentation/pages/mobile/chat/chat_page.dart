import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';
import 'package:pet_shop/data/repositories/customer_chat_repository_impl.dart';
import 'package:pet_shop/domain/entities/chat_entities.dart';
import 'package:pet_shop/presentation/bloc/customer_chat/customer_chat_bloc.dart';
import 'package:pet_shop/presentation/bloc/customer_chat/customer_chat_event.dart';
import 'package:pet_shop/presentation/bloc/customer_chat/customer_chat_state.dart';

class ChatPage extends StatelessWidget {
  final Map<String, dynamic>? selectedPet;

  const ChatPage({super.key, this.selectedPet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerChatBloc(CustomerChatRepositoryImpl()),
      child: ChatPageContent(selectedPet: selectedPet),
    );
  }
}

class ChatPageContent extends StatefulWidget {
  final Map<String, dynamic>? selectedPet;

  const ChatPageContent({super.key, this.selectedPet});

  @override
  State<ChatPageContent> createState() => _ChatPageContentState();
}

class _ChatPageContentState extends State<ChatPageContent> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? user;
  bool _isUploading = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final userData = await authService.value.getUserInfo();
    setState(() {
      user = userData;
    });

    if (user != null && user!['email'] != null) {
      final customerId = user!['email'];
      _conversationId = customerId;

      // Create or get conversation
      final repository = CustomerChatRepositoryImpl();
      await repository.getOrCreateConversation(
        customerId: customerId,
        participantsInfo: {
          customerId: {
            'name': user!['name'] ?? 'Customer',
            'imageUrl': user!['imageUrl'] ?? '',
          },
          'shop_admin': {
            'name': 'Pet Shop',
            'imageUrl': '',
          },
        },
      );

      // Load messages
      if (mounted) {
        context.read<CustomerChatBloc>().add(LoadCustomerMessages(_conversationId!));
      }

      // Auto-fill pet info if provided
      if (widget.selectedPet != null) {
        final pet = widget.selectedPet!;
        _messageController.text =
            'Tôi muốn hỏi thêm thông tin về thú cưng: ${pet['name']}'
            '\nGiống: ${pet['breed'] ?? 'Không xác định'}'
            '\nGiá: ${pet['price'] ?? 'Chưa có giá'}';
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || user == null) return;

    context.read<CustomerChatBloc>().add(
          SendCustomerMessage(
            conversationId: _conversationId!,
            senderId: user!['email'],
            text: text,
          ),
        );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    if (_conversationId == null || user == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // Upload to Firebase Storage
      final customerEmail = user!['email'];
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('${customerEmail}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      // Send image message via BLoC
      if (mounted) {
        context.read<CustomerChatBloc>().add(
              SendCustomerImageMessage(
                conversationId: _conversationId!,
                senderId: user!['email'],
                imageUrl: imageUrl,
              ),
            );
      }

      setState(() => _isUploading = false);
      _scrollToBottom();
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    if (user == null || _conversationId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        title: const Text("Pet Shop"),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<CustomerChatBloc, CustomerChatState>(
              builder: (context, state) {
                if (state is CustomerChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is CustomerChatError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${state.message}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CustomerChatBloc>().add(
                                  LoadCustomerMessages(_conversationId!),
                                );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is CustomerChatLoaded) {
                  final messages = state.messages;

                  // Auto-scroll when messages update
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == user!['email'];
                      final hasImage = msg.imageUrl != null && msg.imageUrl!.isNotEmpty;
                      final hasText = msg.text != null && msg.text!.isNotEmpty;

                      return _buildMessageBubble(
                        message: msg,
                        isMe: isMe,
                        hasImage: hasImage,
                        hasText: hasText,
                      );
                    },
                  );
                }

                return const Center(child: Text('No messages yet'));
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage message,
    required bool isMe,
    required bool hasImage,
    required bool hasText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(message.senderId),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Image-only message
                if (hasImage && !hasText)
                  _buildImage(message.imageUrl!),
                
                // Message with text or image+text
                if (hasText || (hasImage && hasText))
                  Container(
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
                        if (hasImage && hasText) _buildImage(message.imageUrl!),
                        if (hasText)
                          Padding(
                            padding: EdgeInsets.only(top: (hasImage && hasText) ? 8 : 0),
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
                
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    message.timestamp.toLocal().toString().substring(11, 16),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(user!['email']),
        ],
      ),
    );
  }

  Widget _buildAvatar(String userId) {
    final isShop = userId == 'shop_admin';
    final imageUrl = isShop ? '' : (user?['imageUrl'] ?? '');

    return CircleAvatar(
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      backgroundColor: Colors.grey[300],
      radius: 15,
      child: imageUrl.isEmpty
          ? Icon(
              isShop ? Icons.store : Icons.person,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }

  Widget _buildImage(String imageUrl) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
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
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đang tải ảnh lên...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image, color: Color(0xFF00A86B)),
                onPressed: _isUploading ? null : _pickAndSendImage,
                tooltip: 'Gửi hình ảnh',
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: "Nhập nội dung ...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF00A86B),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
