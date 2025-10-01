import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Comprehensive logging utility for recommendation system analysis
class RecommendationLogger {
  static File? _logFile;
  static File? _workspaceFile;
  
  /// Initialize the logger with file path
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/recommendation_analysis.txt');
      
      // Try multiple locations for workspace file
      final workspacePaths = [
        'd:\\Subjects\\FinalReport\\project\\pet_shop\\RECOMMENDATION_ANALYSIS_RESULTS.txt',
        '${directory.path}/RECOMMENDATION_ANALYSIS_RESULTS.txt',
        '/storage/emulated/0/Download/RECOMMENDATION_ANALYSIS_RESULTS.txt',
      ];
      
      // Clear previous logs and add header
      await _logFile!.writeAsString('');
      
      // Try each workspace path until one works
      bool workspaceWritten = false;
      for (final path in workspacePaths) {
        try {
          _workspaceFile = File(path);
          await _workspaceFile!.writeAsString('RECOMMENDATION SYSTEM TEST\n');
          workspaceWritten = true;
          await log('✅ Workspace file created at: $path');
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (!workspaceWritten) {
        await log('⚠️ Cannot write to workspace file, using app documents only');
        _workspaceFile = null;
      }
      
      await log('=' * 80);
      await log('RECOMMENDATION SYSTEM COMPREHENSIVE ANALYSIS');
      await log('Generated at: ${DateTime.now()}');
      await log('=' * 80);
      await log('');
    } catch (e) {
      print('❌ Failed to initialize recommendation logger: $e');
    }
  }
  
  /// Log a message to both console and files
  static Future<void> log(String message) async {
    print(message);
    
    try {
      // Write to app documents
      if (_logFile != null) {
        await _logFile!.writeAsString('$message\n', mode: FileMode.append);
      }
      
      // Write to workspace only if available
      if (_workspaceFile != null) {
        await _workspaceFile!.writeAsString('$message\n', mode: FileMode.append);
      }
    } catch (e) {
      // Silently ignore file write errors to avoid spam
    }
  }
  
  /// Log user data analysis
  static Future<void> logUserAnalysis(Map<String, dynamic> data) async {
    await log('\n📊 USER DATA ANALYSIS');
    await log('-' * 40);
    
    final userId = data['userId'] ?? 'Unknown';
    await log('👤 User ID: $userId');
    
    // Orders analysis
    final orders = data['orders'] as List<dynamic>? ?? [];
    await log('\n🛒 ORDERS ANALYSIS (${orders.length} orders):');
    for (int i = 0; i < orders.length; i++) {
      final order = orders[i] as Map<String, dynamic>;
      await log('  Order ${i + 1}:');
      await log('    - ID: ${order['orderId']}');
      await log('    - Date: ${order['timestamp']}');
      await log('    - Items: ${order['items']?.length ?? 0}');
      
      final items = order['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemData = item as Map<String, dynamic>;
        await log('      • ${itemData['name']} (${itemData['category']}/${itemData['breed']})');
      }
    }
    
    // Viewed pets analysis
    final viewedPets = data['viewedPets'] as List<dynamic>? ?? [];
    await log('\n👀 VIEWED PETS ANALYSIS (${viewedPets.length} pets):');
    for (final pet in viewedPets.take(5)) {
      final petData = pet as Map<String, dynamic>;
      await log('  • ${petData['name']} (${petData['category']}) - ${petData['viewedAt']}');
    }
    
    // Favorites analysis
    final favorites = data['favorites'] as List<dynamic>? ?? [];
    await log('\n💖 FAVORITES ANALYSIS (${favorites.length} pets):');
    for (final fav in favorites) {
      final favData = fav as Map<String, dynamic>;
      await log('  • ${favData['name']} (${favData['category']}) - Created: ${favData['createdAt'] ?? 'No timestamp'}');
    }
    
    // Search history
    final searches = data['searches'] as List<dynamic>? ?? [];
    await log('\n🔍 SEARCH HISTORY (${searches.length} searches):');
    for (final search in searches.take(3)) {
      final searchData = search as Map<String, dynamic>;
      await log('  • "${searchData['query']}" - ${searchData['searchedAt']}');
    }
  }
  
  /// Log scoring calculations
  static Future<void> logScoring(Map<String, dynamic> scores) async {
    await log('\n📈 SCORING CALCULATIONS');
    await log('-' * 40);
    
    final categoryScores = scores['categoryScores'] as Map<String, int>? ?? {};
    await log('🏷️ Category Scores:');
    categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((entry) async {
        await log('  • ${entry.key}: ${entry.value} points');
      });
    
    final breedScores = scores['breedScores'] as Map<String, int>? ?? {};
    await log('\n🐾 Breed Scores (Top 5):');
    final topBreeds = breedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in topBreeds.take(5)) {
      await log('  • ${entry.key}: ${entry.value} points');
    }
  }
  
  /// Log final recommendations
  static Future<void> logRecommendations(List<dynamic> recommendations) async {
    await log('\n🎯 FINAL RECOMMENDATIONS');
    await log('-' * 40);
    await log('Total recommendations: ${recommendations.length}');
    
    await log('\nTop 10 Recommendations:');
    for (int i = 0; i < recommendations.length && i < 10; i++) {
      final rec = recommendations[i] as Map<String, dynamic>;
      await log('  ${i + 1}. ${rec['name']} (${rec['category']})');
      await log('     - Score: ${rec['score']}');
      await log('     - Reason: ${rec['reason']}');
      await log('     - Type: ${rec['type']}');
    }
    
    // Category distribution
    final categoryDist = <String, int>{};
    for (final rec in recommendations) {
      final recData = rec as Map<String, dynamic>;
      final category = recData['category']?.toString() ?? 'Unknown';
      categoryDist[category] = (categoryDist[category] ?? 0) + 1;
    }
    
    await log('\n📊 Recommendation Distribution:');
    final sortedCategoryDist = categoryDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCategoryDist) {
      final percentage = (entry.value / recommendations.length * 100).toStringAsFixed(1);
      await log('  • ${entry.key}: ${entry.value} pets (${percentage}%)');
    }
  }
  
  /// Log performance metrics
  static Future<void> logPerformance(Map<String, dynamic> metrics) async {
    await log('\n⚡ PERFORMANCE METRICS');
    await log('-' * 40);
    
    metrics.forEach((key, value) async {
      await log('$key: $value');
    });
  }
  
  /// Log final analysis and conclusions
  static Future<void> logConclusion(Map<String, dynamic> analysis) async {
    await log('\n🔍 SYSTEM ANALYSIS & CONCLUSIONS');
    await log('=' * 50);
    
    final userPreferences = analysis['userPreferences'] as List<String>? ?? [];
    await log('👤 User Preferences Detected: ${userPreferences.join(", ")}');
    
    final systemAccuracy = analysis['accuracy'] ?? 'Unknown';
    await log('🎯 System Accuracy: $systemAccuracy');
    
    final improvements = analysis['improvements'] as List<String>? ?? [];
    await log('\n💡 Suggested Improvements:');
    for (final improvement in improvements) {
      await log('  • $improvement');
    }
    
    await log('\n✅ Analysis Complete!');
    await log('=' * 80);
  }
  
  /// Get the log file paths for reading
  static Map<String, String?> getLogFilePaths() {
    return {
      'appDocuments': _logFile?.path,
      'workspace': _workspaceFile?.path,
    };
  }
  
  /// Copy final results to workspace
  static Future<void> saveToWorkspace() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        
        // Try to save to workspace file if available
        if (_workspaceFile != null) {
          await _workspaceFile!.writeAsString(content);
          await log('💾 Analysis saved to workspace: ${_workspaceFile!.path}');
        }
        
        // Always save to app documents
        await log('💾 Analysis saved to app documents: ${_logFile!.path}');
        
        // Also try saving to Downloads folder for easy access
        try {
          final downloadsFile = File('/storage/emulated/0/Download/recommendation_analysis_${DateTime.now().millisecondsSinceEpoch}.txt');
          await downloadsFile.writeAsString(content);
          await log('💾 Analysis also saved to Downloads: ${downloadsFile.path}');
        } catch (e) {
          await log('⚠️ Could not save to Downloads folder: $e');
        }
      }
    } catch (e) {
      await log('❌ Error saving to workspace: $e');
    }
  }
  
  /// Force create analysis file with timestamp
  static Future<String?> createAnalysisFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final analysisFile = File('${directory.path}/recommendation_analysis_$timestamp.txt');
      
      if (_logFile != null && await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        await analysisFile.writeAsString(content);
        await log('📁 Analysis file created: ${analysisFile.path}');
        return analysisFile.path;
      }
      return null;
    } catch (e) {
      await log('❌ Error creating analysis file: $e');
      return null;
    }
  }
}