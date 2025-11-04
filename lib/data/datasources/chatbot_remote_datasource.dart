import 'dart:async';
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

  static const Duration _requestTimeout = Duration(seconds: 10);

  static String _autoBaseUrl() {
    // Use cloud n8n instance
    return 'https://minhtam23503.app.n8n.cloud';
  }

  ChatBotRemoteDataSourceImpl({
    required this.client,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? _autoBaseUrl();

  @override
  Future<ChatBotResponseModel> sendMessage(String userId, String message) async {
    final requestModel = ChatBotRequestModel(
      message: message,
      userId: userId,
    );

    try {
      // Try primary and fallback endpoints to support both webhook and webhook-test
      final endpoints = <String>[
        '$baseUrl/webhook/chat',
        '$baseUrl/webhook-test/chat',
      ];

      dynamic lastError;
      for (final url in endpoints) {
        try {
          final response = await client
              .post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: json.encode(requestModel.toJson()),
              )
              .timeout(_requestTimeout);

          print('ChatBot API POST $url -> ${response.statusCode}');
          if (response.statusCode == 200) {
            final responseBody = json.decode(response.body);

            if (responseBody == null) {
              throw Exception('Đã có lỗi xảy ra, vui lòng thử lại sau');
            }

            return ChatBotResponseModel.fromJson(responseBody);
          } else {
            lastError = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
          }
        } on TimeoutException catch (e) {
          lastError = 'Timeout: ${e.message ?? e.toString()}';
          // Try next endpoint
          continue;
        } catch (e) {
          lastError = e;
          // Try next endpoint
          continue;
        }
      }

      throw Exception('Failed to send message to chatbot: $lastError');
    } catch (e) {
      print('ChatBot API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  @override
  Future<bool> checkServiceAvailability() async {
    try {
      final healthEndpoints = <String>[
        '$baseUrl/webhook/health',
        '$baseUrl/webhook-test/health',
      ];

      for (final url in healthEndpoints) {
        try {
          final response = await client
              .get(
                Uri.parse(url),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) return true;
        } catch (_) {
          // Try next health endpoint
          continue;
        }
      }

      return false;
    } catch (e) {
      print('ChatBot Service Health Check Failed: $e');
      return false;
    }
  }
}