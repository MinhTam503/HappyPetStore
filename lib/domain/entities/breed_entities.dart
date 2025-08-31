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
  final String image;
  final int age;
  final String color;
  final double confidence;

  const SuggestedPet({
    required this.id,
    required this.name,
    required this.breed,
    required this.weight,
    required this.image,
    required this.age,
    required this.color,
    required this.confidence,
  });

  factory SuggestedPet.fromMap(Map<String, dynamic> map, double confidence) {
    return SuggestedPet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      image: map['image'] ?? '',
      age: map['age'] ?? 0,
      color: map['color'] ?? '',
      confidence: confidence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'weight': weight,
      'image': image,
      'age': age,
      'color': color,
      'confidence': confidence,
    };
  }

  @override
  String toString() => 'SuggestedPet($name - $breed, confidence: ${confidence.toStringAsFixed(2)})';
}
