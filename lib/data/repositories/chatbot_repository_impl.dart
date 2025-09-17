import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pet_shop/data/datasources/chatbot_remote_datasource.dart';
import 'package:pet_shop/data/models/chatbot_model.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

class ChatBotRepositoryImpl implements ChatBotRepository {
  final ChatBotRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  
  static const String _chatBotHistoryPrefix = 'chatbot_history_';

  ChatBotRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<ChatBotResponse> sendMessage(String userId, String message) async {
    try {
      // Send message to remote chatbot service
      final response = await remoteDataSource.sendMessage(userId, message);
      
      // Enrich pets with missing imageUrl from Firestore
      final enrichedPets = await _enrichPetsWithImageUrl(response.pets);
      final enrichedResponse = ChatBotResponseModel(
        success: response.success,
        status: response.status,
        timestamp: response.timestamp,
        requestId: response.requestId,
        message: response.message,
        messageType: response.messageType,
        pets: enrichedPets,
        totalFound: response.totalFound,
        filtersApplied: response.filtersApplied,
        pagination: response.pagination,
        quickReplies: response.quickReplies,
        actions: response.actions,
      );
      
      // Save user message to local storage
      final userMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
        userId: userId,
      );
      await saveChatBotMessage(userMessage);
      
      // Save bot response with pets and quick replies to local storage
      final botMessage = ChatBotMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_bot',
        text: enrichedResponse.message,
        isUser: false,
        timestamp: DateTime.now(),
        userId: userId,
        pets: enrichedResponse.pets.isNotEmpty ? enrichedResponse.pets : null,
        quickReplies: enrichedResponse.quickReplies.isNotEmpty ? enrichedResponse.quickReplies : null,
        actions: enrichedResponse.actions.isNotEmpty ? enrichedResponse.actions : null,
      );
      await saveChatBotMessage(botMessage);
      
      return enrichedResponse.toEntity();
    } catch (e) {
      print('ChatBot Repository Error: $e');
      rethrow;
    }
  }

  Future<List<ChatBotPet>> _enrichPetsWithImageUrl(List<ChatBotPet> pets) async {
    final enrichedPets = <ChatBotPet>[];
    
    for (final pet in pets) {
      if (pet.imageUrl.isEmpty) {
        try {
          // Fetch pet data from Firestore
          final doc = await FirebaseFirestore.instance
              .collection('Pets')
              .doc(pet.id)
              .get();
          
          if (doc.exists) {
            final data = doc.data()!;
            final enrichedPet = ChatBotPetModel(
              id: pet.id,
              name: data['name'] ?? pet.name,
              breed: data['breed'] ?? pet.breed,
              category: data['category'] ?? pet.category,
              age: data['age']?.toString() ?? pet.age,
              sex: data['sex'] ?? pet.sex,
              weight: data['weight']?.toString() ?? pet.weight,
              price: data['price'] ?? pet.price,
              imageUrl: data['imageUrl'] ?? '',
              about: data['about'] ?? pet.about,
              healthStatus: data['health_status'] ?? pet.healthStatus,
              vaccination: data['vaccination'] ?? pet.vaccination,
              location: data['location'] ?? pet.location,
            );
            enrichedPets.add(enrichedPet);
          } else {
            enrichedPets.add(pet);
          }
        } catch (e) {
          print('Error fetching pet ${pet.id} from Firestore: $e');
          enrichedPets.add(pet);
        }
      } else {
        enrichedPets.add(pet);
      }
    }
    
    return enrichedPets;
  }

  @override
  Future<void> saveChatBotMessage(ChatBotMessage message) async {
    try {
      final historyKey = _chatBotHistoryPrefix + message.userId;
      final existingHistory = await getChatBotHistory(message.userId);
      
      final updatedHistory = [...existingHistory, message];
      final historyJson = updatedHistory
          .map((msg) => ChatBotMessageModel.fromEntity(msg).toJson())
          .toList();
      
      await sharedPreferences.setString(historyKey, json.encode(historyJson));
    } catch (e) {
      print('Save ChatBot Message Error: $e');
      rethrow;
    }
  }

  @override
  Future<List<ChatBotMessage>> getChatBotHistory(String userId) async {
    try {
      final historyKey = _chatBotHistoryPrefix + userId;
      final historyString = sharedPreferences.getString(historyKey);
      
      if (historyString == null || historyString.isEmpty) {
        return [];
      }
      
      final historyJson = json.decode(historyString) as List<dynamic>;
      return historyJson
          .map((json) => ChatBotMessageModel.fromJson(json).toEntity())
          .toList();
    } catch (e) {
      print('Get ChatBot History Error: $e');
      return [];
    }
  }

  @override
  Future<void> clearChatBotHistory(String userId) async {
    try {
      final historyKey = _chatBotHistoryPrefix + userId;
      await sharedPreferences.remove(historyKey);
    } catch (e) {
      print('Clear ChatBot History Error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      return await remoteDataSource.checkServiceAvailability();
    } catch (e) {
      print('ChatBot Service Availability Check Error: $e');
      return false;
    }
  }
}