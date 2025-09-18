class BreedTransaction {
  final String orderId;
  final List<String> breeds;
  final DateTime timestamp;

  const BreedTransaction({
    required this.orderId,
    required this.breeds,
    required this.timestamp,
  });

  @override
  String toString() => 'BreedTransaction(orderId: $orderId, breeds: $breeds)';
}

class BreedAssociation {
  final String breedA;
  final String breedB;
  final int count;
  final double confidence;

  const BreedAssociation({
    required this.breedA,
    required this.breedB,
    required this.count,
    required this.confidence,
  });

  @override
  String toString() => 'BreedAssociation($breedA → $breedB: $count times, confidence: ${confidence.toStringAsFixed(2)})';
}

/// FP-Growth Association Rule (supports multiple items in antecedent/consequent)
class FPGrowthAssociation {
  final List<String> antecedent;
  final List<String> consequent;
  final double confidence;
  final double support;

  const FPGrowthAssociation({
    required this.antecedent,
    required this.consequent,
    required this.confidence,
    required this.support,
  });

  @override
  String toString() => 'FPGrowthAssociation(${antecedent.join(",")} → ${consequent.join(",")}: confidence=${confidence.toStringAsFixed(2)})';
}

class SuggestedPet {
  final String id;
  final String name;
  final String breed;
  final double weight;
  final String imageUrl;
  final int age;
  final String color;
  final double price;
  final double confidence;

  const SuggestedPet({
    required this.id,
    required this.name,
    required this.breed,
    required this.weight,
    required this.imageUrl,
    required this.age,
    required this.color,
    required this.price,
    required this.confidence,
  });

  factory SuggestedPet.fromMap(Map<String, dynamic> map, double confidence) {
    return SuggestedPet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      weight: _parseDouble(map['weight']),
      imageUrl: map['imageUrl'] ?? '',
      age: _parseInt(map['age']),
      color: map['color'] ?? '',
      price: _parseDouble(map['price']),
      confidence: confidence,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'weight': weight,
      'imageUrl': imageUrl,
      'age': age,
      'color': color,
      'price': price,
      'confidence': confidence,
    };
  }

  @override
  String toString() => 'SuggestedPet($name - $breed, confidence: ${confidence.toStringAsFixed(2)})';
}
