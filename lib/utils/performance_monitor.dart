import 'dart:async';

/// Simple performance monitoring utility
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<Duration>> _measurements = {};

  /// Start timing an operation
  static void startTimer(String operationName) {
    final stopwatch = Stopwatch()..start();
    _timers[operationName] = stopwatch;
  }

  /// Stop timing an operation and record the duration
  static Duration? stopTimer(String operationName) {
    final stopwatch = _timers[operationName];
    if (stopwatch == null) return null;
    
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    
    // Record the measurement
    if (!_measurements.containsKey(operationName)) {
      _measurements[operationName] = [];
    }
    _measurements[operationName]!.add(duration);
    
    // Clean up
    _timers.remove(operationName);
    
    return duration;
  }

  /// Get performance statistics for an operation
  static PerformanceStats? getStats(String operationName) {
    final measurements = _measurements[operationName];
    if (measurements == null || measurements.isEmpty) return null;

    final durations = measurements.map((d) => d.inMilliseconds).toList();
    durations.sort();

    final total = durations.reduce((a, b) => a + b);
    final average = total / durations.length;
    final median = durations.length % 2 == 0
        ? (durations[durations.length ~/ 2 - 1] + durations[durations.length ~/ 2]) / 2
        : durations[durations.length ~/ 2].toDouble();

    return PerformanceStats(
      operationName: operationName,
      count: durations.length,
      averageMs: average,
      medianMs: median,
      minMs: durations.first.toDouble(),
      maxMs: durations.last.toDouble(),
      totalMs: total.toDouble(),
    );
  }

  /// Get all performance statistics
  static Map<String, PerformanceStats> getAllStats() {
    final stats = <String, PerformanceStats>{};
    for (final key in _measurements.keys) {
      final stat = getStats(key);
      if (stat != null) {
        stats[key] = stat;
      }
    }
    return stats;
  }

  /// Clear all measurements
  static void clearStats() {
    _measurements.clear();
    _timers.clear();
  }

  /// Time a function execution
  static Future<T> timeOperation<T>(String operationName, Future<T> Function() operation) async {
    startTimer(operationName);
    try {
      final result = await operation();
      return result;
    } finally {
      final duration = stopTimer(operationName);
      if (duration != null) {
      }
    }
  }

  /// Print performance report
  static void printReport() {
    final stats = getAllStats();
    if (stats.isEmpty) {
      return;
    }

    for (final stat in stats.values) {
    }
  }
}

class PerformanceStats {
  final String operationName;
  final int count;
  final double averageMs;
  final double medianMs;
  final double minMs;
  final double maxMs;
  final double totalMs;

  PerformanceStats({
    required this.operationName,
    required this.count,
    required this.averageMs,
    required this.medianMs,
    required this.minMs,
    required this.maxMs,
    required this.totalMs,
  });

  @override
  String toString() {
    return 'PerformanceStats($operationName: ${averageMs.toStringAsFixed(1)}ms avg, ${count} calls)';
  }
}
