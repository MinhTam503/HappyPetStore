import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pet_shop/auth/auth_service.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    fetchUser();
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
    final displayName = user!['displayName'];
    final imageUrl = user!['imageUrl'];

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(customerEmail);
    await conversationRef.collection('messages').add({
      'message': msg,
      'sender': customerEmail,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await conversationRef.update({
      'lastMessage': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
                    final isMe = msg['sender'] == user!['email'];
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              backgroundImage:
                                  NetworkImage(msg['imageUrl'] ?? ""),
                              radius: 15,
                            ),
                          const SizedBox(
                            width: 5,
                          ),
                          Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      isMe ? Colors.blue : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg['message'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              Text(
                                msg['timestamp'] != null
                                    ? (msg['timestamp'] as Timestamp)
                                        .toDate()
                                        .toLocal()
                                        .toString()
                                        .substring(0, 16)
                                    : "Sending ...",
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54),
                              )
                            ],
                          ),
                          if (isMe)
                            const SizedBox(
                              width: 5,
                            ),
                          if (isMe)
                            CircleAvatar(
                              backgroundImage:
                                  NetworkImage(msg['imageUrl'] ?? ""),
                              radius: 15,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type your message ...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
