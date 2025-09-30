// Demo script để test recommendation logging system
// Chạy script này để generate sample logs

import 'package:pet_shop/services/recommendation_logger.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';

Future<void> runRecommendationLoggingDemo() async {
  print('🚀 Starting Recommendation Logging Demo...');
  
  // Initialize logger
  await RecommendationLogger.initialize();
  
  // Simulate recommendation session
  final sessionId = await RecommendationLogger.logSessionStart(
    userId: 'demo_user_123',
    requestedTypes: [RecommendationType.hybrid],
    limit: 10,
    additionalData: {'source': 'demo'},
  );
  
  // Simulate user profile
  final userProfile = UserProfile(
    userId: 'demo_user_123',
    preferredCategories: ['Dog', 'Cat'],
    preferredBreeds: ['Golden Retriever', 'Persian Cat'],
    categoryWeights: {'Dog': 0.8, 'Cat': 0.6},
    breedWeights: {'Golden Retriever': 0.9, 'Persian Cat': 0.7},
    averageSpending: 1500000,
    lastActivity: DateTime.now().subtract(Duration(hours: 2)),
  );
  
  await RecommendationLogger.logUserProfile(
    sessionId: sessionId,
    userProfile: userProfile,
    interactionCount: 25,
    recentCategories: ['Dog', 'Cat'],
  );
  
  // Simulate algorithm executions
  final algorithms = [
    RecommendationType.contentBased,
    RecommendationType.collaborative,
    RecommendationType.trending,
  ];
  
  final algorithmResults = <RecommendationType, List<RecommendationItem>>{};
  
  for (final algorithm in algorithms) {
    final startTime = DateTime.now();
    
    // Simulate processing time
    await Future.delayed(Duration(milliseconds: 100 + (algorithm.index * 50)));
    
    final executionTime = DateTime.now().difference(startTime);
    final resultCount = 5 + (algorithm.index * 2);
    
    // Create mock recommendations
    final recommendations = List.generate(resultCount, (index) => 
      RecommendationItem(
        petId: 'pet_${algorithm.toString().split('.').last}_$index',
        name: 'Demo Pet $index',
        category: index % 2 == 0 ? 'Dog' : 'Cat',
        breed: index % 2 == 0 ? 'Golden Retriever' : 'Persian Cat',
        price: 1000000 + (index * 200000),
        imageUrl: 'https://example.com/pet_$index.jpg',
        score: 0.8 - (index * 0.1),
        reason: 'Demo recommendation reason',
        type: algorithm,
      )
    );
    
    algorithmResults[algorithm] = recommendations;
    
    await RecommendationLogger.logAlgorithmExecution(
      sessionId: sessionId,
      algorithmType: algorithm,
      inputCount: 50,
      outputCount: resultCount,
      executionTime: executionTime,
      weights: {algorithm.toString(): 1.0},
    );
  }
  
  // Simulate hybrid combination
  final combinationStartTime = DateTime.now();
  await Future.delayed(Duration(milliseconds: 50));
  
  final finalResults = algorithmResults.values
      .expand((list) => list)
      .take(10)
      .toList();
  
  final combinationTime = DateTime.now().difference(combinationStartTime);
  
  await RecommendationLogger.logHybridCombination(
    sessionId: sessionId,
    algorithmResults: algorithmResults,
    algorithmWeights: {
      RecommendationType.contentBased: 0.4,
      RecommendationType.collaborative: 0.3,
      RecommendationType.trending: 0.3,
    },
    finalResults: finalResults,
    combinationTime: combinationTime,
  );
  
  // Simulate session completion
  final totalTime = DateTime.now().difference(DateTime.now().subtract(Duration(seconds: 2)));
  
  await RecommendationLogger.logSessionComplete(
    sessionId: sessionId,
    finalRecommendations: finalResults,
    totalTime: totalTime,
    performanceMetrics: {
      'userProfileTimeMs': 150,
      'processingTimeMs': 50,
      'algorithmsExecuted': algorithms.length,
      'totalCandidates': algorithmResults.values.expand((list) => list).length,
      'uniqueCandidates': finalResults.length,
      'finalResults': finalResults.length,
    },
  );
  
  // Simulate user interactions
  for (int i = 0; i < 5; i++) {
    await RecommendationLogger.logUserInteraction(
      userId: 'demo_user_123',
      petId: 'pet_demo_$i',
      interactionType: i % 3 == 0 ? InteractionType.view : 
                      i % 3 == 1 ? InteractionType.favorite : 
                                  InteractionType.cart,
      metadata: {
        'category': i % 2 == 0 ? 'Dog' : 'Cat',
        'source': 'recommendation_section',
        'position': i,
      },
    );
    
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  print('✅ Demo completed! Generated logs for:');
  print('   - 1 recommendation session');
  print('   - 3 algorithm executions');
  print('   - 1 hybrid combination');
  print('   - 5 user interactions');
  print('   - Session: $sessionId');
  
  // Generate analytics report
  final analytics = await RecommendationLogger.generateAnalyticsReport();
  print('📊 Analytics Report:');
  print('   - Total Sessions: ${analytics['sessionStatistics']['totalSessions']}');
  print('   - Success Rate: ${(analytics['sessionStatistics']['successRate'] * 100).toStringAsFixed(1)}%');
  print('   - Total Interactions: ${analytics['userInteractions']['totalInteractions']}');
  
  print('🎯 Log file location: ${RecommendationLogger.logFilePath}');
  print('🔍 Check the analytics page in the app to view detailed logs!');
}