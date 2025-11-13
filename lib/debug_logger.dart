import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Persistent debug logger for tracking widget background events
/// Logs are stored in SharedPreferences and displayed in the Logs page
class DebugLogger {
  static const int maxLogs = 50; // Keep last 50 debug entries
  static const String _logKey = 'debugLogs';

  /// Log an event with timestamp
  static Future<void> log(String event, {String? details, bool isError = false}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'event': event,
      'details': details,
      'isError': isError,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogsJson = prefs.getString(_logKey) ?? '[]';
      final List<dynamic> logs = jsonDecode(existingLogsJson);

      // Add new log entry
      logs.add(logEntry);

      // Keep only last N entries
      if (logs.length > maxLogs) {
        logs.removeRange(0, logs.length - maxLogs);
      }

      await prefs.setString(_logKey, jsonEncode(logs));

      // Also print to console for logcat
      final prefix = isError ? '❌' : '🔍';
      print('$prefix [${DateTime.now()}] $event${details != null ? " | $details" : ""}');
    } catch (e) {
      print('⚠️ Failed to write debug log: $e');
    }
  }

  /// Get all debug logs
  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_logKey) ?? '[]';
      final List<dynamic> logs = jsonDecode(logsJson);
      return logs.cast<Map<String, dynamic>>();
    } catch (e) {
      print('⚠️ Failed to read debug logs: $e');
      return [];
    }
  }

  /// Clear all debug logs
  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
      print('🗑️ Debug logs cleared');
    } catch (e) {
      print('⚠️ Failed to clear debug logs: $e');
    }
  }

  /// Get formatted timestamp for display
  static String formatTimestamp(String iso8601) {
    try {
      final dt = DateTime.parse(iso8601);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (e) {
      return iso8601;
    }
  }
}
