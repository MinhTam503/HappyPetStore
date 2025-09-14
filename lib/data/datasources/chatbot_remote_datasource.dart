import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pet_shop/data/models/chatbot_model.dart';

abstract class ChatBotRemoteDataSource {
  Future<ChatBotResponseModel> sendMessage(String userId, String message);
  Future<bool> checkServiceAvailability();
}

class ChatBotRemoteDataSourceImpl implements ChatBotRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  ChatBotRemoteDataSourceImpl({
    required this.client,
    this.baseUrl = 'http://10.0.2.2:5678',
  });

  @override
  Future<ChatBotResponseModel> sendMessage(String userId, String message) async {
    final requestModel = ChatBotRequestModel(
      userId: userId,
      message: message,
    );

    try {
      final response = await client.post(
        Uri.parse('$baseUrl/webhook/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestModel.toJson()),
      );

      print('ChatBot API Response Status: ${response.statusCode}');
      print('ChatBot API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        return ChatBotResponseModel.fromJson(responseBody);
      } else {
        throw Exception('Failed to send message to chatbot: ${response.statusCode}');
      }
    } catch (e) {
      print('ChatBot API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  @override
  Future<bool> checkServiceAvailability() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/webhook/health'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('ChatBot Service Health Check Failed: $e');
      return false;
    }
  }
}