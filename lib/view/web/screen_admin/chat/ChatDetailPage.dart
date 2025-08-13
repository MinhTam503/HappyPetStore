import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/utils/contants.dart';

import 'components/date_chip.dart';
import 'components/message_row.dart';

class ChatDetailPage extends StatefulWidget {
  final String customerEmail;

  const ChatDetailPage({super.key, required this.customerEmail});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Thông tin shop
  final String shopEmail = 'shop@gmail.com';
  final String shopImage =
      'https://cdn-icons-png.flaticon.com/512/616/616408.png';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
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

    await conversationRef.set({
      'lastMessage': message,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _controller.clear();

    // Cuộn xuống cuối sau khi gửi
    await Future.delayed(const Duration(milliseconds: 60));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) return DateFormat('HH:mm').format(ts.toDate());
    return '';
  }

  String _fmtDay(dynamic ts) {
    if (ts is Timestamp)
      return DateFormat('EEEE, dd/MM/yyyy').format(ts.toDate());
    return '';
  }

  bool _isSameDay(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return false;
    final da = a.toDate(), db = b.toDate();
    return da.year == db.year && da.month == db.month && da.day == db.day;
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
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(.12),
              child: Text(
                widget.customerEmail.isNotEmpty
                    ? widget.customerEmail[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.customerEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Danh sách tin nhắn
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Có lỗi khi tải dữ liệu'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: primaryColor));
                  }
                  final docs = snapshot.data!.docs;

                  // tự cuộn về cuối khi có message mới
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController
                          .jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('Hãy bắt đầu cuộc trò chuyện…'));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = docs[index];
                      final isMe = msg['sender'] == shopEmail;
                      final ts = msg['timestamp'];
                      final showDateHeader = index == 0
                          ? true
                          : !_isSameDay(docs[index - 1]['timestamp'], ts);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader) ...[
                            const SizedBox(height: 8),
                            DateChip(label: _fmtDay(ts)),
                            const SizedBox(height: 8),
                          ],
                          MessageRow(
                            isMe: isMe,
                            avatarUrl:
                                isMe ? shopImage : (msg['imageUrl'] ?? ''),
                            text: (msg['message'] ?? '').toString(),
                            time: _fmtTime(ts),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Input bar
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: IconButton(
                          tooltip: 'Emoji',
                          onPressed: () {},
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 24,
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
