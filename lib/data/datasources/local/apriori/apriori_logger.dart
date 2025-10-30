import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight logger to record Apriori mining runs to a JSON file
/// Format: array of log entries appended over time
/// Types: RUN_START, TRANSACTIONS_INFO, MINING_SUMMARY, SUGGESTED_BREEDS, PET_RESULTS, NO_DATA, RUN_COMPLETE
class AprioriLogger {
  static const String _fileName = 'apriori_logs.json';
  static File? _file;

  static Future<File> _ensure() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$_fileName');
    if (!(await f.exists())) {
      await f.create(recursive: true);
      await f.writeAsString('[]');
    }
    _file = f;
    if (kDebugMode) {
      debugPrint('📄 Apriori logs file path: ${f.path}');
    }
    return f;
  }

  static Future<String> startRun({required Map<String, dynamic> parameters}) async {
    final id = 'apriori_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    await append(id, type: 'RUN_START', data: {
      'parameters': parameters,
    });
    return id;
  }

  static Future<void> append(String runId, {required String type, required Map<String, dynamic> data}) async {
    try {
      final f = await _ensure();
      final content = await f.readAsString();
      final List<dynamic> logs = content.trim().isEmpty ? [] : jsonDecode(content);
      logs.add({
        'runId': runId,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        ...data,
      });
  const encoder = JsonEncoder.withIndent('  ');
  await f.writeAsString(encoder.convert(logs));
      if (kDebugMode) {
        debugPrint('📝 AprioriLogger [$type] appended');
      }
    } catch (e) {
      debugPrint('❌ AprioriLogger error: $e');
    }
  }

  static Future<void> complete(String runId, {required bool success, required Map<String, dynamic> metrics}) async {
    await append(runId, type: 'RUN_COMPLETE', data: {
      'success': success,
      'metrics': metrics,
    });
  }

  /// Returns the absolute path to the Apriori logs file.
  static Future<String> getLogFilePath() async {
    final f = await _ensure();
    return f.path;
  }
}
