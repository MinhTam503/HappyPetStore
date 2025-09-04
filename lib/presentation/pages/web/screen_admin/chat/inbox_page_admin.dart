import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pet_shop/core/constants/app_constants.dart'; // có primaryColor, secondaryColor

import '../../components/empty_state.dart';
import 'ChatDetailPage.dart';
import 'components/conversation_card.dart';

class InboxPageAdmin extends StatefulWidget {
  const InboxPageAdmin({super.key});

  @override
  State<InboxPageAdmin> createState() => _InboxPageAdminState();
}

class _InboxPageAdminState extends State<InboxPageAdmin> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final today = DateTime.now();
      final isSameDay =
          d.year == today.year && d.month == today.month && d.day == today.day;
      return isSameDay
          ? DateFormat('HH:mm').format(d)
          : DateFormat('dd/MM').format(d);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final conversations = FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0.5,
        title: Text(
          AppLocalizations.of(context)!.conversationsList,
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor, 
            fontWeight: FontWeight.w600
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchByEmailOrMessage,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: conversations,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    label: AppLocalizations.of(context)!.errorLoadingData,
                    icon: Icons.forum_outlined,
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyState(
                    label: AppLocalizations.of(context)!.noConversationsYet,
                    icon: Icons.forum_outlined,
                  );
                }

                // Lọc theo keyword
                final q = _searchCtl.text.trim().toLowerCase();
                final docs = snapshot.data!.docs.where((d) {
                  final email = d.id.toString().toLowerCase();
                  final last =
                      (d['lastMessage'] ?? '').toString().toLowerCase();
                  if (q.isEmpty) return true;
                  return email.contains(q) || last.contains(q);
                }).toList();

                if (docs.isEmpty) {
                  return EmptyState(
                    label: AppLocalizations.of(context)!.noMatchingResults,
                    icon: Icons.forum_outlined,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final email = doc.id;

                    final lastMessage = (doc['lastMessage'] ?? '').toString();
                    final ts = doc['timestamp'];
                    final unread = (doc.data() as Map<String, dynamic>)
                            .containsKey('unread')
                        ? (doc['unread'] as num?)?.toInt() ?? 0
                        : 0;

                    // !!! PHẢI return FutureBuilder
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(email)
                          .collection('messages')
                          .where('sender',
                              isEqualTo: email) // chỉ lấy tin khách gửi
                          .orderBy('timestamp', descending: true)
                          .limit(1)
                          .get(),
                      builder: (ctx, snap) {
                        String imageUrl = '';
                        if (snap.hasData && snap.data!.docs.isNotEmpty) {
                          final m = snap.data!.docs.first.data()
                              as Map<String, dynamic>;
                          imageUrl = (m['imageUrl'] ?? '').toString();
                        }

                        // fallback từ users nếu vẫn rỗng
                        if (imageUrl.isEmpty) {
                          return FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: email)
                                .limit(1)
                                .get(),
                            builder: (ctx2, snap2) {
                              if (snap2.hasData &&
                                  snap2.data!.docs.isNotEmpty) {
                                final u = snap2.data!.docs.first.data()
                                    as Map<String, dynamic>;
                                imageUrl = (u['imageUrl'] ?? '').toString();
                              }

                              return ConversationCard(
                                email: email,
                                lastMessage: lastMessage,
                                imageUrl: imageUrl,
                                time: _fmtTime(ts),
                                unread: unread,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatDetailPage(customerEmail: email),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }

                        // có imageUrl rồi thì trả thẳng
                        return ConversationCard(
                          email: email,
                          lastMessage: lastMessage,
                          imageUrl: imageUrl,
                          time: _fmtTime(ts),
                          unread: unread,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatDetailPage(customerEmail: email),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
