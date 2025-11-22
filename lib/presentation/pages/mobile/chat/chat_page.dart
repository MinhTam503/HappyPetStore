import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic>? selectedPet;

  const ChatPage({super.key, this.selectedPet});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? user;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    fetchUser();

    // Nếu có thông tin thú cưng được chọn, tự động điền vào tin nhắn
    if (widget.selectedPet != null) {
      final pet = widget.selectedPet!;
      _messageController.text =
          'Tôi muốn hỏi thêm thông tin về thú cưng: ${pet['name']}'
          '\nGiống: ${pet['breed'] ?? 'Không xác định'}'
          '\nGiá: ${pet['price'] ?? 'Chưa có giá'}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchUser() async {
    final userData = await authService.value.getUserInfo();
    setState(() {
      user = userData;
    });

    // Sau khi có user, mới gọi openChat
    if (user != null && user!['email'] != null) {
      await openChat(user!['email']);
    }
  }

  Future<void> openChat(String customerEmail) async {
    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(customerEmail);

    final doc = await conversationRef.get();

    if (!doc.exists) {
      await conversationRef.set({
        'participants': [customerEmail, 'shop@gmail.com'],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendMessage() async {
    final String msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    final customerEmail = user!['email'];

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(customerEmail);
    await conversationRef.collection('messages').add({
      'message': msg,
      'sender': customerEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await conversationRef.update({
      'lastMessage': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    
    // Scroll to bottom after sending
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

  Future<void> pickAndSendImage() async {
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
      final customerEmail = user!['email'];
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('${customerEmail}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      // Send image message
      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(customerEmail);
      await conversationRef.collection('messages').add({
        'imageUrl': imageUrl,
        'sender': customerEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await conversationRef.update({
        'lastMessage': 'Đã gửi hình ảnh',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isUploading = false;
      });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null || user!['email'] == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messageStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(user!['email'])
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

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
            child: StreamBuilder<QuerySnapshot>(
              stream: messageStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final message = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: message.length,
                  itemBuilder: (context, index) {
                    final msg = message[index];
                    final msgData = msg.data() as Map<String, dynamic>?;
                    if (msgData == null) return const SizedBox.shrink();
                    
                    final isMe = msgData['sender'] == user!['email'];
                    final senderEmail = msgData['sender'];
                    final hasImage = msgData.containsKey('imageUrl') && 
                                    msgData['imageUrl'] != null && 
                                    msgData['imageUrl'].toString().isNotEmpty;
                    final hasText = msgData.containsKey('message') && 
                                   msgData['message'] != null && 
                                   msgData['message'].toString().isNotEmpty;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(senderEmail)
                                  .get(),
                              builder: (context, snapshot) {
                                String avatarUrl = '';
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                  avatarUrl = userData?['imageUrl'] ?? '';
                                }
                                return CircleAvatar(
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                  radius: 15,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                                      : null,
                                );
                              },
                            ),
                          if (!isMe) const SizedBox(width: 8),
                          
                          // Message bubble - wrapped in Flexible to prevent overflow
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Image-only message (no colored bubble)
                                if (hasImage && !hasText)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 250,
                                      maxHeight: 300,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        msgData['imageUrl'],
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
                                
                                // Message with text or image+text (colored bubble)
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
                                        // Image if present (and has text)
                                        if (hasImage && hasText)
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 250,
                                              maxHeight: 300,
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                msgData['imageUrl'],
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
                                        
                                        // Text if present
                                        if (hasText)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: (hasImage && hasText) ? 8 : 0,
                                            ),
                                            child: Text(
                                              msgData['message'],
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
                                    msgData['timestamp'] != null
                                        ? (msgData['timestamp'] as Timestamp)
                                            .toDate()
                                            .toLocal()
                                            .toString()
                                            .substring(11, 16)
                                        : "Sending ...",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (isMe) const SizedBox(width: 8),
                          if (isMe)
                            CircleAvatar(
                              backgroundImage: user!['imageUrl'] != null && user!['imageUrl'].toString().isNotEmpty
                                  ? NetworkImage(user!['imageUrl'])
                                  : null,
                              backgroundColor: Colors.grey[300],
                              radius: 15,
                              child: user!['imageUrl'] == null || user!['imageUrl'].toString().isEmpty
                                  ? const Icon(Icons.person, size: 16, color: Colors.white)
                                  : null,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
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
                // Upload indicator
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
                
                // Input row
                Row(
                  children: [
                    // Image picker button
                    IconButton(
                      icon: const Icon(Icons.image, color: Color(0xFF00A86B)),
                      onPressed: _isUploading ? null : pickAndSendImage,
                      tooltip: 'Gửi hình ảnh',
                    ),
                    
                    // Text input
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
                    
                    // Send button
                    CircleAvatar(
                      backgroundColor: const Color(0xFF00A86B),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
