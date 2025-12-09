import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'components/date_chip.dart';
import 'components/message_row.dart';

class ChatDetailPage extends StatefulWidget {
  final String customerId; // Đổi từ customerEmail sang customerId (uid)

  const ChatDetailPage({super.key, required this.customerId});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Thông tin shop - must match CustomerChatRepositoryImpl.shopId
  final String shopEmail = 'shop_admin';
  final String shopImage =
      'https://cdn-icons-png.flaticon.com/512/616/616408.png';
  
  String _customerImageUrl = '';
  String _customerName = '';

  @override
  void initState() {
    super.initState();
    _loadCustomerAvatar();
  }

  Future<void> _loadCustomerAvatar() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.customerId) // Sử dụng customerId (uid) thay vì query bằng email
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _customerImageUrl = userData['imageUrl'] ?? '';
          _customerName = userData['displayName'] ?? userData['name'] ?? userData['email'] ?? 'Customer';
        });
      }
    } catch (e) {
      // Keep empty if error
    }
  }

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
        .collection('customerConversations')
        .doc(widget.customerId); // Sử dụng customerId thay vì customerEmail

    final messageDoc = conversationRef.collection('messages').doc();
    await messageDoc.set({
      'senderId': shopEmail,
      'text': message,
      'imageUrl': null,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'reactions': {},
    });

    // Update conversation metadata
    final conversationDoc = await conversationRef.get();
    if (conversationDoc.exists) {
      final data = conversationDoc.data() as Map<String, dynamic>;
      final unreadCount = Map<String, int>.from(data['unreadCount'] ?? {});
      unreadCount[widget.customerId] = (unreadCount[widget.customerId] ?? 0) + 1; // Sử dụng customerId
      
      await conversationRef.update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': shopEmail,
        'unreadCount': unreadCount,
      });
    }

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
        .collection('customerConversations')
        .doc(widget.customerId) // Sử dụng customerId thay vì customerEmail
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundImage: _customerImageUrl.isNotEmpty 
                  ? NetworkImage(_customerImageUrl)
                  : null,
              backgroundColor: Theme.of(context)
                                    .colorScheme.primary.withOpacity(.12),
              child: _customerImageUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _customerName.isNotEmpty ? _customerName : 'Customer', // Hiển thị tên thay vì uid
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).appBarTheme.foregroundColor, 
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Danh sách tin nhắn
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(AppLocalizations.of(context)!.errorLoadingChatData));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return  Center(
                        child: CircularProgressIndicator(color: Theme.of(context)
                                    .colorScheme.primary));
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
                    return Center(
                        child: Text(AppLocalizations.of(context)!.startConversation));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = docs[index];
                      final isMe = msg['senderId'] == shopEmail;
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
                                isMe ? shopImage : _customerImageUrl,
                            text: (msg['text'] ?? '').toString(),
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
                        hintText: AppLocalizations.of(context)!.enterMessage,
                        filled: true,
                        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                        ),
                        prefixIcon: IconButton(
                          tooltip: AppLocalizations.of(context)!.emoji,
                          onPressed: () {},
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                                    .colorScheme.primary,
                    radius: 24,
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary),
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
