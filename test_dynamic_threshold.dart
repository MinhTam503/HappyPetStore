// Test Dynamic Threshold for Golden Retriever
import 'dart:io';

void main() async {
  print('🔍 Testing Dynamic Breed Threshold for Golden Retriever...');
  
  // Simulate the breed scores from log
  final breedScores = {
    'Chim hoạ mi': 20,
    'Cá vàng': 20, 
    'Chim yến phụng': 27,
    'Chim sáo': 10,
    'Husky': 10,
    'Chihuahua': 20,
    'Golden Retriever': 17
  };
  
  final favoriteBreeds = ['Chim yến phụng', 'Chim hoạ mi', 'Cá vàng', 'Chihuahua', 'Golden Retriever', 'Chim sáo', 'Husky'];
  
  print('\n📊 Breed Analysis:');
  print('   Top breed score: ${breedScores.values.reduce((a, b) => a > b ? a : b)}');
  
  // Test different threshold strategies
  final strategies = [
    {'name': 'Fixed Top-2', 'breeds': favoriteBreeds.take(2).toList()},
    {'name': 'Fixed Top-3', 'breeds': favoriteBreeds.take(3).toList()},
    {'name': 'Dynamic 50%', 'threshold': 0.5},
    {'name': 'Dynamic 60%', 'threshold': 0.6},
    {'name': 'Dynamic 70%', 'threshold': 0.7},
  ];
  
  print('\n🎯 Strategy Comparison:');
  
  for (final strategy in strategies) {
    List<String> selectedBreeds;
    
    if (strategy.containsKey('threshold')) {
      final threshold = strategy['threshold'] as double;
      final topScore = breedScores.values.reduce((a, b) => a > b ? a : b);
      final minScore = (topScore * threshold).round();
      
      selectedBreeds = favoriteBreeds.where((breed) {
        final score = breedScores[breed] ?? 0;
        return score >= minScore;
      }).take(4).toList();
      
      print('   ${strategy['name']}: threshold=$minScore → $selectedBreeds');
    } else {
      selectedBreeds = strategy['breeds'] as List<String>;
      print('   ${strategy['name']}: → $selectedBreeds');
    }
    
    final hasGolden = selectedBreeds.contains('Golden Retriever');
    print('     Golden Retriever included: ${hasGolden ? "✅" : "❌"}');
  }
  
  // Test optimal threshold for Golden Retriever inclusion
  print('\n🐕 Golden Retriever Inclusion Analysis:');
  final goldenScore = breedScores['Golden Retriever']!;
  final topScore = breedScores.values.reduce((a, b) => a > b ? a : b);
  final goldenRatio = goldenScore / topScore;
  
  print('   Golden Retriever score: $goldenScore');
  print('   Top breed score: $topScore');
  print('   Golden ratio: ${(goldenRatio * 100).toStringAsFixed(1)}%');
  print('   Needed threshold: ≤${(goldenRatio * 100).toStringAsFixed(1)}% to include Golden');
  
  // Recommend optimal threshold
  final optimalThreshold = (goldenRatio * 0.95); // 5% buffer
  print('   Recommended threshold: ${(optimalThreshold * 100).toStringAsFixed(1)}%');
  
  // Test recommended threshold
  final recommendedMinScore = (topScore * optimalThreshold).round();
  final optimalBreeds = favoriteBreeds.where((breed) {
    final score = breedScores[breed] ?? 0;
    return score >= recommendedMinScore;
  }).toList();
  
  print('\n✅ Optimal Configuration:');
  print('   Threshold: ${(optimalThreshold * 100).toStringAsFixed(1)}% (min score: $recommendedMinScore)');
  print('   Selected breeds: $optimalBreeds');
  print('   Golden Retriever included: ${optimalBreeds.contains('Golden Retriever') ? "✅ YES" : "❌ NO"}');
  
  // Create recommendation
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final analysisFile = File('DYNAMIC_THRESHOLD_ANALYSIS_$timestamp.txt');
  
  final content = '''
=== DYNAMIC BREED THRESHOLD ANALYSIS ===
Generated: ${DateTime.now().toIso8601String()}

CURRENT BREED SCORES:
${breedScores.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

GOLDEN RETRIEVER ANALYSIS:
- Score: $goldenScore
- Top breed score: $topScore  
- Ratio: ${(goldenRatio * 100).toStringAsFixed(1)}%
- Current rank: ${favoriteBreeds.indexOf('Golden Retriever') + 1}

THRESHOLD STRATEGY COMPARISON:
- Fixed top-2: ${favoriteBreeds.take(2).contains('Golden Retriever') ? "✅" : "❌"} Golden included
- Fixed top-3: ${favoriteBreeds.take(3).contains('Golden Retriever') ? "✅" : "❌"} Golden included  
- Dynamic 50%: ${favoriteBreeds.where((b) => (breedScores[b] ?? 0) >= (topScore * 0.5).round()).contains('Golden Retriever') ? "✅" : "❌"} Golden included
- Optimal ${(optimalThreshold * 100).toStringAsFixed(1)}%: ${optimalBreeds.contains('Golden Retriever') ? "✅" : "❌"} Golden included

RECOMMENDED IMPLEMENTATION:
threshold = max(0.6, goldenRatio * 0.95) // Ensure Golden inclusion with buffer

EXPECTED RESULTS:
✅ Golden Retriever will be included in breed targeting
✅ Dynamic threshold adapts to user preferences
✅ Better coverage of user's preferred breeds
✅ Balanced recommendations across all favorite breeds
''';
  
  await analysisFile.writeAsString(content);
  print('\n📄 Analysis saved to: ${analysisFile.path}');
  
  print('\n🚀 Next Steps:');
  print('   1. Update threshold to 60% (ensures Golden inclusion)');
  print('   2. Test with real app to verify UI changes');
  print('   3. Monitor user engagement with Golden Retriever recommendations');
}