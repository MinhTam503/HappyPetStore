import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChatDetailPage extends StatefulWidget {
  final String customerEmail;

  const ChatDetailPage({super.key, required this.customerEmail});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String shopEmail = 'shop@gmail.com';
  final String shopImage =
      'https://cdn-icons-png.flaticon.com/512/616/616408.png'; // ảnh mặc định

  void sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.customerEmail);

    await conversationRef.collection('messages').add({
      'message': message,
      'sender': shopEmail,
      'imageUrl': shopImage,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await conversationRef.update({
      'lastMessage': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _controller.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.customerEmail)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text("Chat với ${widget.customerEmail}")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messages,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController
                        .jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final msg = docs[index];
                    final isMe = msg['sender'] == shopEmail;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              backgroundImage: msg['imageUrl'] != null
                                  ? NetworkImage(msg['imageUrl'])
                                  : null,
                              child: msg['imageUrl'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                              onBackgroundImageError: (_, __) {}, // Tránh lỗi crash nếu ảnh lỗi
                            ),

                          const SizedBox(width: 5),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['message'],
                              style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black),
                            ),
                          ),
                          if (isMe) const SizedBox(width: 5),
                          if (isMe)
                            const CircleAvatar(
                              backgroundImage: NetworkImage(
                                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQu5GX1lkI6T4INseXlhyZhaGMtq07LNid9Tw&s'),
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
