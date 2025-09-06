import 'package:cloud_firestore/cloud_firestore.dart';

class WordGenerationLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Log word generation analytics to Firebase for review and improvements
  static Future<void> logWordGeneration({
    required String prompt,
    required String difficulty,
    required List<String> services,
    required Map<String, int> wordCounts,
    required List<String> sampleWords,
    required String finalService,
    required bool success,
    String? gameId,
    String? gameName,
    String? error,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'prompt': prompt,
        'difficulty': difficulty,
        'services': services, // e.g., ['datamuse', 'gemini'] or ['demo_ai']
        'wordCounts': wordCounts, // e.g., {'datamuse': 20, 'gemini': 16}
        'sampleWords': sampleWords.take(10).toList(), // First 10 words for analysis
        'finalService': finalService, // e.g., 'DATAMUSE + GEMINI AI'
        'success': success,
        'error': error,
        'totalWords': sampleWords.length,
        'gameId': gameId,
        'gameName': gameName,
        'metadata': {
          'appVersion': '1.0.0',
          'platform': 'web',
          ...?additionalData,
        },
      };
      
      // If we have a gameId, store as subcollection under the game
      if (gameId != null) {
        await _firestore
            .collection('games')
            .doc(gameId)
            .collection('word_generation_logs')
            .add(logData);
        
        print('📊 Analytics: Logged word generation to Firebase under game $gameId');
      } else {
        // Fallback to root collection for backwards compatibility
        await _firestore
            .collection('word_generation_logs')
            .add(logData);
        
        print('📊 Analytics: Logged word generation to Firebase (no game context)');
      }
      
    } catch (e) {
      // Don't let logging failures break the app
      print('⚠️  Analytics: Failed to log to Firebase: $e');
    }
  }
  
  /// Log pattern detection analytics
  static Future<void> logPatternDetection({
    required String prompt,
    String? detectedPattern,
    String? detectedEnding,
    int? detectedLength,
    bool datamuseCanHandle = false,
    String? gameId,
  }) async {
    try {
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'pattern_detection',
        'prompt': prompt,
        'detectedPattern': detectedPattern,
        'detectedEnding': detectedEnding,
        'detectedLength': detectedLength,
        'datamuseCanHandle': datamuseCanHandle,
        'gameId': gameId,
      };
      
      if (gameId != null) {
        await _firestore
            .collection('games')
            .doc(gameId)
            .collection('analytics')
            .add(logData);
      } else {
        await _firestore
            .collection('word_generation_analytics')
            .add(logData);
      }
      
    } catch (e) {
      print('⚠️  Analytics: Failed to log pattern detection: $e');
    }
  }
  
  /// Log service performance metrics
  static Future<void> logServicePerformance({
    required String service,
    required String prompt,
    required Duration responseTime,
    required int wordsGenerated,
    required bool success,
    String? error,
    String? gameId,
  }) async {
    try {
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'service_performance',
        'service': service, // 'datamuse', 'gemini', 'demo_ai'
        'prompt': prompt,
        'responseTimeMs': responseTime.inMilliseconds,
        'wordsGenerated': wordsGenerated,
        'success': success,
        'error': error,
        'gameId': gameId,
      };
      
      if (gameId != null) {
        await _firestore
            .collection('games')
            .doc(gameId)
            .collection('analytics')
            .add(logData);
      } else {
        await _firestore
            .collection('word_generation_analytics')
            .add(logData);
      }
      
    } catch (e) {
      print('⚠️  Analytics: Failed to log service performance: $e');
    }
  }
  
  /// Log teacher usage patterns
  static Future<void> logTeacherUsage({
    required String teacherName,
    required String prompt,
    required String gameName,
    String? userId,
  }) async {
    try {
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'teacher_usage',
        'teacherName': teacherName,
        'prompt': prompt,
        'gameName': gameName,
        'userId': userId,
      };
      
      await _firestore
          .collection('teacher_usage_analytics')
          .add(logData);
      
    } catch (e) {
      print('⚠️  Analytics: Failed to log teacher usage: $e');
    }
  }
  
  /// Log word validation issues for improvement
  static Future<void> logWordValidation({
    required String prompt,
    required List<String> invalidWords,
    required String reason,
    required String service,
    String? gameId,
  }) async {
    try {
      final logData = {
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'word_validation',
        'prompt': prompt,
        'invalidWords': invalidWords,
        'reason': reason, // e.g., 'wrong_length', 'wrong_ending', 'inappropriate'
        'service': service,
        'gameId': gameId,
      };
      
      if (gameId != null) {
        await _firestore
            .collection('games')
            .doc(gameId)
            .collection('analytics')
            .add(logData);
      } else {
        await _firestore
            .collection('word_generation_analytics')
            .add(logData);
      }
      
    } catch (e) {
      print('⚠️  Analytics: Failed to log word validation: $e');
    }
  }
  
  /// Get analytics summary (for admin dashboard)
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();
      
      final snapshot = await _firestore
          .collection('word_generation_logs')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();
      
      final logs = snapshot.docs.map((doc) => doc.data()).toList();
      
      // Calculate metrics
      final totalRequests = logs.length;
      final successfulRequests = logs.where((log) => log['success'] == true).length;
      final failedRequests = totalRequests - successfulRequests;
      
      final serviceUsage = <String, int>{};
      final promptTypes = <String, int>{};
      
      for (final log in logs) {
        final service = log['finalService'] as String?;
        if (service != null) {
          serviceUsage[service] = (serviceUsage[service] ?? 0) + 1;
        }
        
        final prompt = (log['prompt'] as String? ?? '').toLowerCase();
        if (prompt.contains('cvc')) {
          promptTypes['CVC patterns'] = (promptTypes['CVC patterns'] ?? 0) + 1;
        } else if (prompt.contains('ending')) {
          promptTypes['Ending patterns'] = (promptTypes['Ending patterns'] ?? 0) + 1;
        } else if (prompt.contains('rhym')) {
          promptTypes['Rhyming'] = (promptTypes['Rhyming'] ?? 0) + 1;
        } else if (prompt.contains('sound')) {
          promptTypes['Phonics'] = (promptTypes['Phonics'] ?? 0) + 1;
        } else {
          promptTypes['General topics'] = (promptTypes['General topics'] ?? 0) + 1;
        }
      }
      
      return {
        'totalRequests': totalRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
        'successRate': totalRequests > 0 ? successfulRequests / totalRequests : 0.0,
        'serviceUsage': serviceUsage,
        'promptTypes': promptTypes,
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      };
      
    } catch (e) {
      print('⚠️  Analytics: Failed to get summary: $e');
      return {};
    }
  }
}