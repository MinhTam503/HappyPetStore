import 'package:cloud_firestore/cloud_firestore.dart';

class SearchHistoryModel {
  final String query;
  final DateTime searchedAt;
  final bool isImageSearch;
  final String? imageUrl;

  SearchHistoryModel({
    required this.query,
    required this.searchedAt,
    this.isImageSearch = false,
    this.imageUrl,
  });

  Map<String, dynamic> toFirestore() => {
    'query': query,
    'searchedAt': FieldValue.serverTimestamp(),
    'searchedAtMillis': DateTime.now().millisecondsSinceEpoch,
    'isImageSearch': isImageSearch,
    'imageUrl': imageUrl,
  };

  static SearchHistoryModel fromFirestore(Map<String, dynamic> data) {
    final Timestamp? ts = data['searchedAt'];
    return SearchHistoryModel(
      query: data['query'] ?? '',
      searchedAt: ts?.toDate() ?? 
        DateTime.fromMillisecondsSinceEpoch(data['searchedAtMillis'] ?? 0),
      isImageSearch: data['isImageSearch'] ?? false,
      imageUrl: data['imageUrl'],
    );
  }
}