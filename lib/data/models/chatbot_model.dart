import 'package:pet_shop/domain/entities/chatbot_entity.dart';

class ChatBotMessageModel extends ChatBotMessage {
  const ChatBotMessageModel({
    required super.id,
    required super.text,
    required super.isUser,
    required super.timestamp,
    required super.userId,
    super.pets,
    super.quickReplies,
    super.actions,
  });

  factory ChatBotMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatBotMessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      pets: json['pets'] != null 
          ? (json['pets'] as List<dynamic>)
              .map((e) => ChatBotPetModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      quickReplies: json['quickReplies'] != null
          ? (json['quickReplies'] as List<dynamic>)
              .map((e) => ChatBotQuickReplyModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      actions: json['actions'] != null
          ? (json['actions'] as List<dynamic>)
              .map((e) => ChatBotActionModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'pets': pets?.map((e) => ChatBotPetModel.fromEntity(e).toJson()).toList(),
      'quickReplies': quickReplies?.map((e) => ChatBotQuickReplyModel.fromEntity(e).toJson()).toList(),
      'actions': actions?.map((e) => ChatBotActionModel.fromEntity(e).toJson()).toList(),
    };
  }

  factory ChatBotMessageModel.fromEntity(ChatBotMessage entity) {
    return ChatBotMessageModel(
      id: entity.id,
      text: entity.text,
      isUser: entity.isUser,
      timestamp: entity.timestamp,
      userId: entity.userId,
      pets: entity.pets,
      quickReplies: entity.quickReplies,
      actions: entity.actions,
    );
  }

  ChatBotMessage toEntity() {
    return ChatBotMessage(
      id: id,
      text: text,
      isUser: isUser,
      timestamp: timestamp,
      userId: userId,
      pets: pets,
      quickReplies: quickReplies,
      actions: actions,
    );
  }
}

class ChatBotPetModel extends ChatBotPet {
  const ChatBotPetModel({
    required super.id,
    required super.name,
    required super.breed,
    required super.category,
    required super.age,
    required super.sex,
    required super.weight,
    required super.price,
    required super.imageUrl,
    required super.about,
    super.healthStatus,
    super.vaccination,
    super.location,
    super.seller,
    super.display,
  });

  factory ChatBotPetModel.fromJson(Map<String, dynamic> json) {
    return ChatBotPetModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      breed: json['breed']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      age: json['age']?.toString() ?? '',
      sex: json['sex']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      price: json['price'] as num? ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
      healthStatus: json['health_status']?.toString(),
      vaccination: json['vaccination']?.toString(),
      location: json['location']?.toString(),
      seller: json['seller'] != null 
          ? ChatBotSellerModel.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      display: json['display'] != null 
          ? ChatBotDisplayModel.fromJson(json['display'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'category': category,
      'age': age,
      'sex': sex,
      'weight': weight,
      'price': price,
      'imageUrl': imageUrl,
      'about': about,
      'health_status': healthStatus,
      'vaccination': vaccination,
      'location': location,
      'seller': seller != null ? ChatBotSellerModel.fromEntity(seller!).toJson() : null,
      'display': display != null ? ChatBotDisplayModel.fromEntity(display!).toJson() : null,
    };
  }

  factory ChatBotPetModel.fromEntity(ChatBotPet entity) {
    return ChatBotPetModel(
      id: entity.id,
      name: entity.name,
      breed: entity.breed,
      category: entity.category,
      age: entity.age,
      sex: entity.sex,
      weight: entity.weight,
      price: entity.price,
      imageUrl: entity.imageUrl,
      about: entity.about,
      healthStatus: entity.healthStatus,
      vaccination: entity.vaccination,
      location: entity.location,
      seller: entity.seller,
      display: entity.display,
    );
  }
}

class ChatBotSellerModel extends ChatBotSeller {
  const ChatBotSellerModel({
    required super.name,
    required super.phone,
    super.rating,
  });

  factory ChatBotSellerModel.fromJson(Map<String, dynamic> json) {
    return ChatBotSellerModel(
      name: json['name'] as String,
      phone: json['phone'] as String,
      rating: json['rating'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'rating': rating,
    };
  }

  factory ChatBotSellerModel.fromEntity(ChatBotSeller entity) {
    return ChatBotSellerModel(
      name: entity.name,
      phone: entity.phone,
      rating: entity.rating,
    );
  }
}

class ChatBotDisplayModel extends ChatBotDisplay {
  const ChatBotDisplayModel({
    required super.priceFormatted,
    required super.ageFormatted,
    required super.weightFormatted,
    required super.shortDescription,
  });

  factory ChatBotDisplayModel.fromJson(Map<String, dynamic> json) {
    return ChatBotDisplayModel(
      priceFormatted: json['price_formatted'] as String,
      ageFormatted: json['age_formatted'] as String,
      weightFormatted: json['weight_formatted'] as String,
      shortDescription: json['short_description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price_formatted': priceFormatted,
      'age_formatted': ageFormatted,
      'weight_formatted': weightFormatted,
      'short_description': shortDescription,
    };
  }

  factory ChatBotDisplayModel.fromEntity(ChatBotDisplay entity) {
    return ChatBotDisplayModel(
      priceFormatted: entity.priceFormatted,
      ageFormatted: entity.ageFormatted,
      weightFormatted: entity.weightFormatted,
      shortDescription: entity.shortDescription,
    );
  }
}

class ChatBotQuickReplyModel extends ChatBotQuickReply {
  const ChatBotQuickReplyModel({
    required super.text,
    required super.action,
    required super.payload,
  });

  factory ChatBotQuickReplyModel.fromJson(Map<String, dynamic> json) {
    return ChatBotQuickReplyModel(
      text: json['text'] as String,
      action: json['action'] as String,
      payload: json['payload'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'action': action,
      'payload': payload,
    };
  }

  factory ChatBotQuickReplyModel.fromEntity(ChatBotQuickReply entity) {
    return ChatBotQuickReplyModel(
      text: entity.text,
      action: entity.action,
      payload: entity.payload,
    );
  }
}

class ChatBotActionModel extends ChatBotAction {
  const ChatBotActionModel({
    required super.type,
    required super.text,
    super.url,
    super.phone,
  });

  factory ChatBotActionModel.fromJson(Map<String, dynamic> json) {
    return ChatBotActionModel(
      type: json['type']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      url: json['url']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'url': url,
      'phone': phone,
    };
  }

  factory ChatBotActionModel.fromEntity(ChatBotAction entity) {
    return ChatBotActionModel(
      type: entity.type,
      text: entity.text,
      url: entity.url,
      phone: entity.phone,
    );
  }
}

class ChatBotPaginationModel extends ChatBotPagination {
  const ChatBotPaginationModel({
    required super.currentPage,
    required super.perPage,
    required super.totalPages,
    required super.hasNext,
    required super.hasPrevious,
  });

  factory ChatBotPaginationModel.fromJson(Map<String, dynamic> json) {
    return ChatBotPaginationModel(
      currentPage: json['current_page'] as int,
      perPage: json['per_page'] as int,
      totalPages: json['total_pages'] as int,
      hasNext: json['has_next'] as bool,
      hasPrevious: json['has_previous'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'per_page': perPage,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }

  factory ChatBotPaginationModel.fromEntity(ChatBotPagination entity) {
    return ChatBotPaginationModel(
      currentPage: entity.currentPage,
      perPage: entity.perPage,
      totalPages: entity.totalPages,
      hasNext: entity.hasNext,
      hasPrevious: entity.hasPrevious,
    );
  }
}

class ChatBotResponseModel extends ChatBotResponse {
  const ChatBotResponseModel({
    required super.success,
    required super.status,
    super.timestamp,
    super.requestId,
    required super.message,
    required super.messageType,
    required super.pets,
    required super.totalFound,
    super.filtersApplied,
    super.pagination,
    required super.quickReplies,
    required super.actions,
  });

  factory ChatBotResponseModel.fromJson(Map<String, dynamic> json) {
    // Handle the new API format from your test examples
    if (json['reply'] != null) {
      // New format with reply, pets, actions
      final reply = json['reply'] as String;
      final actions = json['actions'] as List<dynamic>? ?? [];
      
      // Extract pets from actions if type is LIST
      List<ChatBotPet> extractedPets = [];
      for (final action in actions) {
        if (action['type'] == 'LIST' && action['items'] != null) {
          final items = action['items'] as List<dynamic>;
          extractedPets.addAll(
            items.map((item) => ChatBotPetModel.fromJson(item as Map<String, dynamic>))
          );
        }
      }
      
      // Parse pets embedded in reply text if format contains IDs
      final (cleanReply, embeddedPets) = _extractPetsFromReply(reply);
      extractedPets.addAll(embeddedPets);
      
      return ChatBotResponseModel(
        success: true,
        status: 'success',
        timestamp: json['metadata']?['timestamp'] as String?,
        requestId: null,
        message: cleanReply,
        messageType: 'text',
        pets: extractedPets,
        totalFound: extractedPets.length,
        filtersApplied: null,
        pagination: null,
        quickReplies: [],
        actions: [], // Don't parse actions as they have different format
      );
    }
    
    // Fallback to old format handling
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    return ChatBotResponseModel(
      success: json['success'] as bool? ?? false,
      status: json['status'] as String? ?? 'error',
      timestamp: json['timestamp'] as String?,
      requestId: json['request_id'] as String?,
      message: data['message'] as String? ?? 'No response',
      messageType: data['message_type'] as String? ?? 'error',
      pets: data['pets'] != null 
          ? (data['pets'] as List<dynamic>)
              .map((e) => ChatBotPetModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      totalFound: data['total_found'] as int? ?? 0,
      filtersApplied: data['filters_applied'] as Map<String, dynamic>?,
      pagination: json['pagination'] != null
          ? ChatBotPaginationModel.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      quickReplies: json['quick_replies'] != null
          ? (json['quick_replies'] as List<dynamic>)
              .map((e) => ChatBotQuickReplyModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      actions: json['actions'] != null
          ? (json['actions'] as List<dynamic>)
              .map((e) => ChatBotActionModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  // Extract pets from reply text with format "Name - Price - Status - Info - (id: ID)"
  static (String, List<ChatBotPet>) _extractPetsFromReply(String reply) {
    // Updated pattern to match both formats:
    // Format 1: "Name - Price ₫ - Status - Info - (id: ID)"
    // Format 2: "Name - Price - Status - Breed, Sex, Age, Weight - (id: ID)"
    final petPattern = RegExp(
      r'([^-\n]+) - ([\d.]+(?:\.\d+)?)[\s₫]+(?:₫\s*)?- ([^-]+) - ([^-]+) - \(id: ([^)]+)\)',
      multiLine: true
    );
    final matches = petPattern.allMatches(reply);
    
    if (matches.isEmpty) {
      return (reply, []);
    }
    
    final pets = <ChatBotPet>[];
    final List<String> petLines = [];
    
    for (final match in matches) {
      final name = match.group(1)?.trim() ?? '';
      final priceStr = match.group(2)?.trim().replaceAll('.', '').replaceAll('₫', '').trim() ?? '0';
      // final status = match.group(3)?.trim() ?? ''; // Not used - usually "Còn hàng"
      final info = match.group(4)?.trim() ?? '';
      final id = match.group(5)?.trim() ?? '';
      
      final price = int.tryParse(priceStr) ?? 0;
      
      // Parse info for breed, sex, age, weight
      final infoParts = info.split(', ');
      String breed = 'Không rõ';
      String sex = 'Không rõ';
      String age = 'Không rõ';
      String weight = 'Không rõ';
      String category = 'Dogs';
      
      if (infoParts.isNotEmpty) {
        breed = infoParts[0];
        category = _getCategoryFromBreed(breed);
      }
      if (infoParts.length > 1) sex = infoParts[1];
      if (infoParts.length > 2) age = infoParts[2].replaceAll(' tuổi', '');
      if (infoParts.length > 3) weight = infoParts[3].replaceAll(' nặng ', '').replaceAll('kg', '');
      
      pets.add(ChatBotPetModel(
        id: id,
        name: name,
        breed: breed,
        category: category,
        age: age,
        sex: sex,
        weight: weight,
        price: price,
        imageUrl: '', // Will be fetched from Firestore
        about: info,
      ));
      
      // Track which lines contain pet info
      petLines.add(match.group(0)!);
    }
    
    // Remove pet info lines from reply
    String cleanReply = reply;
    for (final line in petLines) {
      cleanReply = cleanReply.replaceAll(line, '');
    }
    
    // Clean up empty lines and keep only meaningful text
    cleanReply = cleanReply.split('\n')
        .map((line) => line.trim())
        .where((line) => 
          line.isNotEmpty && 
          !line.startsWith('(id:') &&
          !petPattern.hasMatch(line))
        .join('\n')
        .trim();
    
    // If no meaningful text remains, use a default message
    if (cleanReply.isEmpty && pets.isNotEmpty) {
      cleanReply = 'Tôi tìm thấy ${pets.length} thú cưng phù hợp với yêu cầu của bạn:';
    }
    
    return (cleanReply, pets);
  }
  
  static String _getCategoryFromBreed(String breed) {
    final lowerBreed = breed.toLowerCase();
    
    // Dog breeds
    if (lowerBreed.contains('husky') || 
        lowerBreed.contains('golden') || 
        lowerBreed.contains('chihuahua') || 
        lowerBreed.contains('phốc') ||
        lowerBreed.contains('bacgie') ||
        lowerBreed.contains('retriever')) {
      return 'Dogs';
    }
    
    // Cat breeds
    if (lowerBreed.contains('mèo') || 
        lowerBreed.contains('ba tư') || 
        lowerBreed.contains('xiêm') ||
        lowerBreed.contains('scottish') ||
        lowerBreed.contains('munchkin') ||
        lowerBreed.contains('anh lông ngắn')) {
      return 'Cats';
    }
    
    // Fish species
    if (lowerBreed.contains('cá') || 
        lowerBreed.contains('koi') || 
        lowerBreed.contains('betta') ||
        lowerBreed.contains('vàng') ||
        lowerBreed.contains('neon') ||
        lowerBreed.contains('bảy màu')) {
      return 'Fish';
    }
    
    // Birds
    if (lowerBreed.contains('chim') || 
        lowerBreed.contains('yến phụng') || 
        lowerBreed.contains('hoạ mi') ||
        lowerBreed.contains('chào mào') ||
        lowerBreed.contains('sáo') ||
        lowerBreed.contains('cu gáy')) {
      return 'Birds';
    }
    
    return 'Dogs'; // Default
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'status': status,
      'timestamp': timestamp,
      'request_id': requestId,
      'data': {
        'message': message,
        'message_type': messageType,
        'pets': pets.map((e) => ChatBotPetModel.fromEntity(e).toJson()).toList(),
        'total_found': totalFound,
        'filters_applied': filtersApplied,
      },
      'pagination': pagination != null 
          ? ChatBotPaginationModel.fromEntity(pagination!).toJson() 
          : null,
      'quick_replies': quickReplies.map((e) => ChatBotQuickReplyModel.fromEntity(e).toJson()).toList(),
      'actions': actions.map((e) => ChatBotActionModel.fromEntity(e).toJson()).toList(),
    };
  }

  factory ChatBotResponseModel.fromEntity(ChatBotResponse entity) {
    return ChatBotResponseModel(
      success: entity.success,
      status: entity.status,
      timestamp: entity.timestamp,
      requestId: entity.requestId,
      message: entity.message,
      messageType: entity.messageType,
      pets: entity.pets,
      totalFound: entity.totalFound,
      filtersApplied: entity.filtersApplied,
      pagination: entity.pagination,
      quickReplies: entity.quickReplies,
      actions: entity.actions,
    );
  }

  ChatBotResponse toEntity() {
    return ChatBotResponse(
      success: success,
      status: status,
      timestamp: timestamp,
      requestId: requestId,
      message: message,
      messageType: messageType,
      pets: pets,
      totalFound: totalFound,
      filtersApplied: filtersApplied,
      pagination: pagination,
      quickReplies: quickReplies,
      actions: actions,
    );
  }
}

class ChatBotRequestModel {
  final String message;
  final String userId;
  final String? sessionId;

  const ChatBotRequestModel({
    required this.message,
    required this.userId,
    this.sessionId,
  });

  factory ChatBotRequestModel.fromJson(Map<String, dynamic> json) {
    return ChatBotRequestModel(
      message: json['message'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'userId': userId,
    };
  }
}