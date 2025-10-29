import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pet_shop/domain/entities/recommendation_entities.dart';

/// Service to log recommendation system performance and results
class RecommendationLogger {
  static const String _logFileName = 'recommendation_logs.json';
  static late File _logFile;
  static bool _initialized = false;
  static bool prettyPrint = true; // Toggle pretty formatting
  static bool _perUserMode = false;
  static String? _currentLogUserId;

  static Future<void> initialize({String? userId, bool perUserFile = false, bool clearExisting = false}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      final wantsPerUser = perUserFile && (userId != null && userId.isNotEmpty);
    final targetFileName = wantsPerUser
      ? 'recommendation_logs_${_sanitizeFileSegment(userId)}.json'
          : _logFileName;
      final targetPath = '${directory.path}/$targetFileName';

      // Already initialized: decide whether to switch, clear, or no-op
      if (_initialized) {
        // If current mode is per-user and a call tries to downgrade to default, ignore
        if (_perUserMode && !wantsPerUser) {
          if (clearExisting) await _writeRawLogs([]);
          return;
        }

        // If same file target
        if (_logFile.path == targetPath) {
          if (clearExisting) await _writeRawLogs([]);
          return;
        }

        // If switching to another per-user context
        if (wantsPerUser && userId != _currentLogUserId) {
          _perUserMode = true;
          _currentLogUserId = userId;
          _logFile = File(targetPath);
          if (clearExisting) {
            await _ensureFileExists();
            await _writeRawLogs([]);
          } else if (!await _logFile.exists()) {
            await _logFile.create(recursive: true);
            await _writeRawLogs([]);
          }
          print('📊 RecommendationLogger switched to user file: ${_logFile.path}');
          return;
        }

        // If initialized to default and asked again for default with optional clear
        if (!wantsPerUser && _logFile.path != targetPath) {
          // Switching to default file explicitly
          _perUserMode = false;
          _currentLogUserId = null;
          _logFile = File(targetPath);
          if (clearExisting) {
            await _ensureFileExists();
            await _writeRawLogs([]);
          } else if (!await _logFile.exists()) {
            await _logFile.create(recursive: true);
            await _writeRawLogs([]);
          }
          print('📊 RecommendationLogger switched to default file: ${_logFile.path}');
          return;
        }

        // Otherwise, no-op
        return;
      }

      // Not initialized yet: set up as requested
      _perUserMode = wantsPerUser;
      _currentLogUserId = wantsPerUser ? userId : null;
      _logFile = File(targetPath);
      if (clearExisting) {
        await _ensureFileExists();
        await _writeRawLogs([]);
      } else {
        if (!await _logFile.exists()) {
          await _logFile.create(recursive: true);
          await _writeRawLogs([]);
        }
      }
      _initialized = true;
      print('📊 RecommendationLogger initialized at: ${_logFile.path}');
    } catch (e) {
      print('❌ Failed to initialize RecommendationLogger: $e');
    }
  }

  /// Log recommendation session start
  static Future<String> logSessionStart({
    required String userId,
    required List<RecommendationType> requestedTypes,
    required int limit,
    Map<String, dynamic>? additionalData,
  }) async {
    final sessionId = _generateSessionId();
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'SESSION_START',
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'requestedTypes': requestedTypes.map((t) => t.toString()).toList(),
      'limit': limit,
      'additionalData': additionalData ?? {},
    };

    await _writeLog(logEntry);
    print('🚀 Recommendation session started: $sessionId for user: $userId');
    return sessionId;
  }

  /// Log user profile data
  static Future<void> logUserProfile({
    required String sessionId,
    required UserProfile userProfile,
    required int interactionCount,
    required List<String> recentCategories,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'USER_PROFILE',
      'timestamp': timestamp.toIso8601String(),
      'userProfile': {
        'userId': userProfile.userId,
        'preferredCategories': userProfile.preferredCategories,
        'preferredBreeds': userProfile.preferredBreeds,
        'categoryWeights': userProfile.categoryWeights,
        'breedWeights': userProfile.breedWeights,
        'averageSpending': userProfile.averageSpending,
        'lastActivity': userProfile.lastActivity.toIso8601String(),
        'interactionCount': interactionCount,
        'recentCategories': recentCategories,
      },
    };

    await _writeLog(logEntry);
    print('👤 User profile logged for session: $sessionId');
  }

  /// Log data fetching performance
  static Future<void> logDataFetching({
    required String sessionId,
    required String dataType,
    required int count,
    required Duration fetchTime,
    String? error,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'DATA_FETCHING',
      'timestamp': timestamp.toIso8601String(),
      'dataType': dataType,
      'count': count,
      'fetchTimeMs': fetchTime.inMilliseconds,
      'success': error == null,
      'error': error,
    };

    await _writeLog(logEntry);
    print('📊 Data fetching logged: $dataType (${fetchTime.inMilliseconds}ms, $count items)');
  }

  /// Log algorithm execution
  static Future<void> logAlgorithmExecution({
    required String sessionId,
    required RecommendationType algorithmType,
    required int inputCount,
    required int outputCount,
    required Duration executionTime,
    required Map<String, double> weights,
    String? error,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'ALGORITHM_EXECUTION',
      'timestamp': timestamp.toIso8601String(),
      'algorithmType': algorithmType.toString(),
      'inputCount': inputCount,
      'outputCount': outputCount,
      'executionTimeMs': executionTime.inMilliseconds,
      'weights': weights,
      'success': error == null,
      'error': error,
    };

    await _writeLog(logEntry);
    print('🧠 Algorithm executed: $algorithmType (${executionTime.inMilliseconds}ms, $outputCount results)');
  }

  /// Log hybrid algorithm combination
  static Future<void> logHybridCombination({
    required String sessionId,
    required Map<RecommendationType, List<RecommendationItem>> algorithmResults,
    required Map<RecommendationType, double> algorithmWeights,
    required List<RecommendationItem> finalResults,
    required Duration combinationTime,
  }) async {
    final timestamp = DateTime.now();
    
    final algorithmSummary = algorithmResults.map((type, items) => MapEntry(
      type.toString(),
      {
        'count': items.length,
        'weight': algorithmWeights[type] ?? 0.0,
        'avgScore': items.isEmpty ? 0.0 : items.map((i) => i.score).reduce((a, b) => a + b) / items.length,
        'topPets': items.take(3).map((i) => {
          'petId': i.petId,
          'score': i.score,
          'reason': i.reason,
        }).toList(),
      },
    ));

    final logEntry = {
      'sessionId': sessionId,
      'type': 'HYBRID_COMBINATION',
      'timestamp': timestamp.toIso8601String(),
      'algorithmSummary': algorithmSummary,
      'finalResultsCount': finalResults.length,
      'combinationTimeMs': combinationTime.inMilliseconds,
      'finalResults': finalResults.map((item) => {
        'petId': item.petId,
        'score': item.score,
        'reason': item.reason,
        'algorithmType': item.type.toString(),
      }).toList(),
    };

    await _writeLog(logEntry);
    print('🔄 Hybrid combination logged: ${finalResults.length} final results in ${combinationTime.inMilliseconds}ms');
  }

  /// Log recommendation session completion
  static Future<void> logSessionComplete({
    required String sessionId,
    required List<RecommendationItem> finalRecommendations,
    required Duration totalTime,
    required Map<String, dynamic> performanceMetrics,
    String? error,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'SESSION_COMPLETE',
      'timestamp': timestamp.toIso8601String(),
      'success': error == null,
      'totalTimeMs': totalTime.inMilliseconds,
      'recommendationCount': finalRecommendations.length,
      'performanceMetrics': performanceMetrics,
      'recommendations': finalRecommendations.map((item) => {
        'petId': item.petId,
        'score': item.score,
        'reason': item.reason,
        'name': item.name,
        'breed': item.breed,
        'algorithmType': item.type.toString(),
      }).toList(),
      'error': error,
    };

    await _writeLog(logEntry);
    
    if (error == null) {
      print('✅ Recommendation session completed: $sessionId (${totalTime.inMilliseconds}ms, ${finalRecommendations.length} recommendations)');
    } else {
      print('❌ Recommendation session failed: $sessionId - $error');
    }
  }

  /// Log user interaction tracking
  static Future<void> logUserInteraction({
    required String userId,
    required String petId,
    required InteractionType interactionType,
    Map<String, dynamic>? metadata,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'type': 'USER_INTERACTION',
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'petId': petId,
      'interactionType': interactionType.toString(),
      'metadata': metadata ?? {},
    };

    await _writeLog(logEntry);
    print('👆 User interaction logged: $interactionType on pet $petId');
  }

  /// Log performance metrics
  static Future<void> logPerformanceMetrics({
    required String sessionId,
    required Map<String, dynamic> metrics,
  }) async {
    final timestamp = DateTime.now();
    
    final logEntry = {
      'sessionId': sessionId,
      'type': 'PERFORMANCE_METRICS',
      'timestamp': timestamp.toIso8601String(),
      'metrics': metrics,
    };

    await _writeLog(logEntry);
    print('📈 Performance metrics logged for session: $sessionId');
  }

  /// Get logs for a specific date range
  static Future<List<Map<String, dynamic>>> getLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? sessionId,
    String? logType,
  }) async {
    try {
      if (!await _logFile.exists()) return [];
      
      final content = await _logFile.readAsString();
      final List<dynamic> logs = jsonDecode(content);
      
      List<Map<String, dynamic>> filteredLogs = logs.cast<Map<String, dynamic>>();
      
      if (startDate != null) {
        filteredLogs = filteredLogs.where((log) {
          final logTime = DateTime.parse(log['timestamp']);
          return logTime.isAfter(startDate) || logTime.isAtSameMomentAs(startDate);
        }).toList();
      }
      
      if (endDate != null) {
        filteredLogs = filteredLogs.where((log) {
          final logTime = DateTime.parse(log['timestamp']);
          return logTime.isBefore(endDate) || logTime.isAtSameMomentAs(endDate);
        }).toList();
      }
      
      if (sessionId != null) {
        filteredLogs = filteredLogs.where((log) => log['sessionId'] == sessionId).toList();
      }
      
      if (logType != null) {
        filteredLogs = filteredLogs.where((log) => log['type'] == logType).toList();
      }
      
      return filteredLogs;
    } catch (e) {
      print('❌ Error reading logs: $e');
      return [];
    }
  }

  /// Reformat existing log file to pretty or compact JSON
  static Future<void> reformatLogFile({bool pretty = true}) async {
    try {
      if (!await _logFile.exists()) return;
      final content = await _logFile.readAsString();
      if (content.trim().isEmpty) return;
      final List<dynamic> logs = jsonDecode(content);
      await _writeRawLogs(logs, forcePretty: pretty);
      print('📝 Log file reformatted to ${pretty ? 'pretty' : 'compact'} JSON');
    } catch (e) {
      print('❌ Error reformatting log file: $e');
    }
  }

  /// Generate analytics report
  static Future<Map<String, dynamic>> generateAnalyticsReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final logs = await getLogs(startDate: startDate, endDate: endDate);
    
    final sessionLogs = logs.where((log) => log['type'] == 'SESSION_COMPLETE').toList();
    final interactionLogs = logs.where((log) => log['type'] == 'USER_INTERACTION').toList();
    
    final successfulSessions = sessionLogs.where((log) => log['success'] == true).length;
    final failedSessions = sessionLogs.where((log) => log['success'] == false).length;
    
    final avgResponseTime = sessionLogs.isEmpty ? 0.0 : 
        sessionLogs.map((log) => log['totalTimeMs'] as int).reduce((a, b) => a + b) / sessionLogs.length;
    
    final interactionTypes = <String, int>{};
    for (final log in interactionLogs) {
      final type = log['interactionType'] as String;
      interactionTypes[type] = (interactionTypes[type] ?? 0) + 1;
    }
    
    return {
      'reportGeneratedAt': DateTime.now().toIso8601String(),
      'reportPeriod': {
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      },
      'sessionStatistics': {
        'totalSessions': sessionLogs.length,
        'successfulSessions': successfulSessions,
        'failedSessions': failedSessions,
        'successRate': sessionLogs.isEmpty ? 0.0 : successfulSessions / sessionLogs.length,
        'averageResponseTimeMs': avgResponseTime,
      },
      'userInteractions': {
        'totalInteractions': interactionLogs.length,
        'interactionTypes': interactionTypes,
      },
      'performanceMetrics': {
        'fastSessions': sessionLogs.where((log) => (log['totalTimeMs'] as int) < 1000).length,
        'slowSessions': sessionLogs.where((log) => (log['totalTimeMs'] as int) > 5000).length,
      },
    };
  }

  /// Clear old logs (keep only last N days)
  static Future<void> clearOldLogs({int keepDays = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      final logs = await getLogs();
      
      final filteredLogs = logs.where((log) {
        final logTime = DateTime.parse(log['timestamp']);
        return logTime.isAfter(cutoffDate);
      }).toList();
      
      await _logFile.writeAsString(jsonEncode(filteredLogs));
      print('🧹 Cleared logs older than $keepDays days');
    } catch (e) {
      print('❌ Error clearing old logs: $e');
    }
  }

  /// Get log file path for external access
  static String get logFilePath => _logFile.path;

  // Private methods
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'rec_${timestamp}_$random';
  }

  static Future<void> _writeLog(Map<String, dynamic> logEntry) async {
    try {
      if (!_initialized) await initialize(userId: _currentLogUserId, perUserFile: _perUserMode);
      
      // Read existing logs
      final content = await _logFile.readAsString();
      final List<dynamic> logs = content.isEmpty ? [] : jsonDecode(content);
      
      // Add new log entry
      logs.add(logEntry);
      
      // Write back to file
      await _writeRawLogs(logs);
    } catch (e) {
      print('❌ Error writing log: $e');
    }
  }

  static Future<void> clearLogs() async {
    try {
      if (!_initialized) await initialize(userId: _currentLogUserId, perUserFile: _perUserMode);
      await _writeRawLogs([]);
      print('🧹 Recommendation logs cleared at: ${_logFile.path}');
    } catch (e) {
      print('❌ Error clearing logs: $e');
    }
  }

  static Future<void> _ensureFileExists() async {
    if (!await _logFile.exists()) {
      await _logFile.create(recursive: true);
    }
  }

  static Future<void> _writeRawLogs(List<dynamic> logs, {bool? forcePretty}) async {
    final encoder = (forcePretty ?? prettyPrint)
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    await _logFile.writeAsString(encoder.convert(logs));
  }

  static String _sanitizeFileSegment(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}