import 'dart:io';

// Simple test for breed-first targeting logic
void main() async {
  print('🎯 TESTING BREED-FIRST TARGETING LOGIC');
  print('=====================================');
  
  // Mock user preferences (simulating what we get from Firebase)
  final Map<String, dynamic> userPreferences = {
    'favoriteBreeds': ['Chim yến phụng', 'Golden Retriever', 'Persian Cat'],
    'breedScores': {
      'Chim yến phụng': 15,  // High score from orders/favorites
      'Golden Retriever': 8,
      'Persian Cat': 5,
    },
    'favoriteCategories': ['Birds', 'Dogs', 'Cats'],
    'categoryScores': {
      'Birds': 20,
      'Dogs': 15,
      'Cats': 8,
    }
  };
  
  // Mock pet database
  final List<Map<String, dynamic>> mockPets = [
    {'id': 'p1', 'name': 'Yến Phụng Baby', 'breed': 'Chim yến phụng', 'category': 'Birds', 'price': 2500000},
    {'id': 'p2', 'name': 'Yến Phụng Adult', 'breed': 'Chim yến phụng', 'category': 'Birds', 'price': 3500000},
    {'id': 'p3', 'name': 'Chim sẻ', 'breed': 'Chim sẻ', 'category': 'Birds', 'price': 500000},
    {'id': 'p4', 'name': 'Chim cảnh', 'breed': 'Chim cảnh', 'category': 'Birds', 'price': 800000},
    {'id': 'p5', 'name': 'Golden Puppy', 'breed': 'Golden Retriever', 'category': 'Dogs', 'price': 15000000},
    {'id': 'p6', 'name': 'German Shepherd', 'breed': 'German Shepherd', 'category': 'Dogs', 'price': 12000000},
  ];
  
  print('\n📊 USER PREFERENCES:');
  print('   Breed scores: ${userPreferences['breedScores']}');
  print('   Category scores: ${userPreferences['categoryScores']}');
  
  // SIMULATE BREED-FIRST RECOMMENDATION LOGIC
  List<Map<String, dynamic>> recommendations = [];
  final favoriteBreeds = userPreferences['favoriteBreeds'] as List<String>;
  final breedScores = userPreferences['breedScores'] as Map<String, int>;
  final categoryScores = userPreferences['categoryScores'] as Map<String, int>;
  
  print('\n🎯 PHASE 1: BREED-SPECIFIC TARGETING');
  print('=====================================');
  
  // Phase 1: Breed-specific recommendations (60% of slots)
  final int maxBreedSlots = (15 * 0.6).round(); // 9 slots for breeds
  
  for (final breed in favoriteBreeds.take(2)) {
    if (recommendations.length >= maxBreedSlots) break;
    
    final breedScore = breedScores[breed] ?? 0;
    print('\n🔍 Searching breed: "$breed" (score: $breedScore)');
    
    // Find pets of this specific breed
    final breedPets = mockPets.where((pet) => pet['breed'] == breed).toList();
    print('   Found ${breedPets.length} pets of breed "$breed"');
    
    for (final pet in breedPets) {
      if (recommendations.length >= maxBreedSlots) break;
      
      // Calculate breed-specific score
      final recommendationScore = breedScore > 15 ? 0.98 : 
                                breedScore > 10 ? 0.92 : 
                                breedScore > 5 ? 0.85 : 0.75;
      
      final recommendation = {
        ...pet,
        'score': recommendationScore,
        'reason': 'Chính xác giống "$breed" bạn yêu thích (điểm breed: $breedScore)',
        'type': 'BREED-SPECIFIC'
      };
      
      recommendations.add(recommendation);
      print('   ✅ Added BREED-MATCH: "${pet['name']}" (score: $recommendationScore)');
    }
  }
  
  print('\n📂 PHASE 2: CATEGORY-LEVEL TARGETING');
  print('====================================');
  
  // Phase 2: Category-level recommendations (remaining slots)
  final existingPetIds = recommendations.map((r) => r['id']).toSet();
  final sortedCategories = categoryScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  // SMART FILTERING: Strongly prioritize breed matches - avoid same category duplicates
  final breedCategoriesUsed = recommendations.map((r) => r['category']).toSet();
  final hasGoodBreedMatches = recommendations.where((r) => r['type'] == 'BREED-SPECIFIC').length >= 2;
  
  final categoriesToSearch = sortedCategories
      .where((entry) => 
        (!breedCategoriesUsed.contains(entry.key) || !hasGoodBreedMatches) && // Skip same categories if we have good breed matches
        recommendations.length < (15 * 0.9).round() // Only if we really need more
      )
      .take(hasGoodBreedMatches ? 0 : 1); // No category matches if we have 2+ good breed matches
  
  for (final categoryEntry in categoriesToSearch) {
    if (recommendations.length >= 15) break;
    
    final category = categoryEntry.key;
    final score = categoryEntry.value;
    print('\n🔍 Searching category: "$category" (score: $score)');
    
    // Find pets in this category (excluding already recommended)
    final categoryPets = mockPets.where((pet) => 
      pet['category'] == category && !existingPetIds.contains(pet['id'])
    ).toList();
    
    print('   Found ${categoryPets.length} new pets in category "$category"');
    
    for (final pet in categoryPets) {
      if (recommendations.length >= 15) break;
      
      // Lower scoring for category-level matches
      final recommendationScore = score > 20 ? 0.65 : // Reduced 
                                 score > 10 ? 0.55 : // Reduced
                                 score > 5 ? 0.45 : 0.35; // Much lower
      
      final recommendation = {
        ...pet,
        'score': recommendationScore,
        'reason': 'Khám phá thêm trong danh mục ${category.toLowerCase()}',
        'type': 'CATEGORY-LEVEL'
      };
      
      recommendations.add(recommendation);
      existingPetIds.add(pet['id']!);
      print('   ✅ Added CATEGORY-MATCH: "${pet['name']}" (score: $recommendationScore)');
    }
  }
  
  // RESULTS ANALYSIS
  print('\n📋 FINAL RECOMMENDATION RESULTS');
  print('===============================');
  print('Total recommendations: ${recommendations.length}');
  
  final breedSpecific = recommendations.where((r) => r['type'] == 'BREED-SPECIFIC').length;
  final categoryLevel = recommendations.where((r) => r['type'] == 'CATEGORY-LEVEL').length;
  
  print('   Breed-specific: $breedSpecific (${(breedSpecific/recommendations.length*100).toStringAsFixed(1)}%)');
  print('   Category-level: $categoryLevel (${(categoryLevel/recommendations.length*100).toStringAsFixed(1)}%)');
  
  print('\n🎯 TARGETING VERIFICATION:');
  final yenPhungCount = recommendations.where((r) => r['breed'] == 'Chim yến phụng').length;
  final otherBirdsCount = recommendations.where((r) => r['category'] == 'Birds' && r['breed'] != 'Chim yến phụng').length;
  
  print('   "Chim yến phụng" recommendations: $yenPhungCount');
  print('   Other birds recommendations: $otherBirdsCount');
  
  if (yenPhungCount > otherBirdsCount) {
    print('   ✅ SUCCESS: System correctly prioritizes specific breed over general category!');
  } else {
    print('   ❌ ISSUE: System still recommends too many general birds');
  }
  
  print('\n📝 DETAILED RECOMMENDATIONS:');
  print('============================');
  recommendations.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  
  for (int i = 0; i < recommendations.length; i++) {
    final rec = recommendations[i];
    print('${i+1}. ${rec['name']} (${rec['breed']})');
    print('   Score: ${rec['score']}, Type: ${rec['type']}');
    print('   Reason: ${rec['reason']}');
    print('');
  }
  
  // Save results to file
  final logContent = StringBuffer();
  logContent.writeln('BREED-FIRST TARGETING TEST RESULTS');
  logContent.writeln('Generated at: ${DateTime.now()}');
  logContent.writeln('');
  logContent.writeln('USER PREFERENCES:');
  logContent.writeln('Breed scores: ${userPreferences['breedScores']}');
  logContent.writeln('Category scores: ${userPreferences['categoryScores']}');
  logContent.writeln('');
  logContent.writeln('RESULTS SUMMARY:');
  logContent.writeln('Total recommendations: ${recommendations.length}');
  logContent.writeln('Breed-specific: $breedSpecific (${(breedSpecific/recommendations.length*100).toStringAsFixed(1)}%)');
  logContent.writeln('Category-level: $categoryLevel (${(categoryLevel/recommendations.length*100).toStringAsFixed(1)}%)');
  logContent.writeln('"Chim yến phụng" recommendations: $yenPhungCount');
  logContent.writeln('Other birds recommendations: $otherBirdsCount');
  logContent.writeln('');
  logContent.writeln('TARGETING SUCCESS: ${yenPhungCount > otherBirdsCount ? "YES" : "NO"}');
  logContent.writeln('');
  
  for (int i = 0; i < recommendations.length; i++) {
    final rec = recommendations[i];
    logContent.writeln('${i+1}. ${rec['name']} (${rec['breed']}) - Score: ${rec['score']} - Type: ${rec['type']}');
  }
  
  try {
    await File('BREED_TARGETING_TEST_RESULTS.txt').writeAsString(logContent.toString());
    print('💾 Results saved to: BREED_TARGETING_TEST_RESULTS.txt');
  } catch (e) {
    print('⚠️  Could not save to file: $e');
  }
  
  print('\n🎉 BREED-FIRST TARGETING TEST COMPLETED!');
}