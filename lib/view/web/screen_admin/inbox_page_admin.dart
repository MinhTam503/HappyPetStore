import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ChatDetailPage.dart';

class InboxPageAdmin extends StatelessWidget {
  const InboxPageAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final conversations = FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("Danh sách cuộc trò chuyện"),),
      body: StreamBuilder<QuerySnapshot>(
        stream: conversations,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final email = doc.id;
              final lastMessage = doc['lastMessage'] ?? '';

              return Card(
                elevation: 5,
                child: ListTile(
                  title: Text(email),
                  subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailPage(customerEmail: email),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
