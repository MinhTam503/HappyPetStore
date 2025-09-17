// Test script for new ChatBot JSON format
void main() {
  // Example JSON response from N8N HappyPet API
  final sampleResponse = '''
{
  "success": true,
  "status": "ok",
  "timestamp": "2025-09-15T10:30:00.000Z",
  "request_id": "req_1726398600_abc123",
  "data": {
    "message": "Tôi tìm thấy 2 chú cá phù hợp với yêu cầu của bạn",
    "message_type": "success",
    "pets": [
      {
        "id": "1729250415537",
        "name": "Ca vang",
        "breed": "Cá vàng",
        "category": "Fish",
        "age": "4",
        "sex": "Female",
        "weight": "5",
        "price": 5000000,
        "imageUrl": "https://firebasestorage.googleapis.com/v0/b/adopt-pet-d1c88.appspot.com/o/1729250414526.jpg?alt=media&token=b43d7a05-d306-434a-bb6a-0d45883da016",
        "about": "Study the grammar lessons that are typically included in each level: A1, A2, B1, B1+, B2. There are three or more exercises and an explanation in each lesson, and feedback for every single question!",
        "health_status": "Khỏe mạnh",
        "vaccination": "Đầy đủ",
        "location": "Hà Nội",
        "seller": {
          "name": "Happy Pet Store",
          "phone": "0901234567",
          "rating": 4.5
        },
        "display": {
          "price_formatted": "5.000.000 VNĐ",
          "age_formatted": "4 tháng tuổi",
          "weight_formatted": "5 kg",
          "short_description": "Study the grammar lessons that are typically included in each level..."
        }
      }
    ],
    "total_found": 2,
    "filters_applied": {
      "category": "Fish",
      "breed": "Cá vàng",
      "price_range": {
        "min": 1000000,
        "max": 10000000
      }
    }
  },
  "pagination": {
    "current_page": 1,
    "per_page": 5,
    "total_pages": 1,
    "has_next": false,
    "has_previous": false
  },
  "quick_replies": [
    {
      "text": "Tìm chó cưng",
      "action": "search",
      "payload": "category=Dog"
    },
    {
      "text": "Xem mèo cảnh",
      "action": "search", 
      "payload": "category=Cat"
    },
    {
      "text": "Cá cảnh",
      "action": "search",
      "payload": "category=Fish"
    }
  ],
  "actions": [
    {
      "type": "view_details",
      "text": "Xem chi tiết",
      "url": "/pet-details/{pet_id}"
    },
    {
      "type": "contact_seller",
      "text": "Liên hệ",
      "phone": "0901234567"
    }
  ]
}
''';

  print('Sample ChatBot Response JSON:');
  print(sampleResponse);
}