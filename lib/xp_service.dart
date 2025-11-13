import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'lifequest_widget.dart';
import 'debug_logger.dart';
import 'dart:math';

class LifeQuestService {
  static bool _isRefreshing = false;
  static DateTime? _lastRefreshTime;
  static const Duration _refreshCooldown = Duration(milliseconds: 500); // Reduced from 2s to 0.5s

  /// Main refresh method with debouncing and error handling
  Future<void> refreshXP() async {
    // Debouncing: prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      _log('⚠️ Refresh already in progress, skipping duplicate call');
      await DebugLogger.log('XP_REFRESH_DEBOUNCED', details: 'Already refreshing', isError: false);
      return;
    }

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _refreshCooldown) {
      final cooldownRemaining = _refreshCooldown.inMilliseconds - now.difference(_lastRefreshTime!).inMilliseconds;
      _log('⚠️ Refresh called too soon, skipping (cooldown: ${_refreshCooldown.inSeconds}s)');
      await DebugLogger.log('XP_REFRESH_COOLDOWN', details: 'Cooldown ${cooldownRemaining}ms remaining', isError: false);
      return;
    }

    _isRefreshing = true;
    _lastRefreshTime = now;
    await DebugLogger.log('XP_REFRESH_STARTED', details: 'Beginning XP calculation');

    try {
      await _performRefresh();
      await DebugLogger.log('XP_REFRESH_COMPLETE', details: 'XP calculation finished');
    } catch (e, stackTrace) {
      _log('❌ Critical error in refreshXP: $e');
      _log('Stack trace: $stackTrace');
      await DebugLogger.log('XP_REFRESH_EXCEPTION', details: e.toString(), isError: true);
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Load cached tasks from SharedPreferences
  Future<List<Map<String, dynamic>>> _loadCachedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('cachedTasks');
    if (cachedJson == null || cachedJson.isEmpty) {
      _log('📂 No cached tasks found');
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      final tasks = decoded.cast<Map<String, dynamic>>();
      _log('📂 Loaded ${tasks.length} cached tasks');
      return tasks;
    } catch (e) {
      _log('⚠️ Failed to load cached tasks: $e');
      return [];
    }
  }

  /// Save tasks to cache (keep only 200 most recent)
  Future<void> _saveCachedTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    // Sort by completion time (newest first)
    tasks.sort((a, b) {
      final aTime = _parseDateTime(a['completed_at']) ?? DateTime(1970);
      final bTime = _parseDateTime(b['completed_at']) ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // Keep only 200 most recent
    final tasksToSave = tasks.take(200).toList();

    try {
      await prefs.setString('cachedTasks', jsonEncode(tasksToSave));
      _log('💾 Cached ${tasksToSave.length} tasks');
    } catch (e) {
      _log('⚠️ Failed to save cached tasks: $e');
    }
  }

  /// Merge fetched and cached tasks, removing duplicates by completed_at
  List<Map<String, dynamic>> _mergeTasks(
    List<Map<String, dynamic>> fetchedTasks,
    List<Map<String, dynamic>> cachedTasks,
  ) {
    final Map<String, Map<String, dynamic>> taskMap = {};

    // Add cached tasks first (use completed_at as unique key)
    for (final task in cachedTasks) {
      final completedAt = task['completed_at'];
      if (completedAt != null) {
        taskMap[completedAt.toString()] = task;
      }
    }

    // Add/overwrite with fetched tasks (they're more up-to-date)
    for (final task in fetchedTasks) {
      final completedAt = task['completed_at'];
      if (completedAt != null) {
        taskMap[completedAt.toString()] = task;
      }
    }

    _log('🔀 Merged ${cachedTasks.length} cached + ${fetchedTasks.length} fetched = ${taskMap.length} unique tasks');
    return taskMap.values.toList();
  }

  Future<void> _performRefresh() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔹 Get previous level for level-up detection
    final previousLevel = prefs.getInt('level') ?? 0;

    // 🔹 Load settings with validation
    final apiKey = prefs.getString('apiKey') ?? '';
    if (apiKey.isEmpty) {
      _log('⚠️ No API key configured, skipping Todoist fetch');
      await DebugLogger.log('NO_API_KEY', details: 'API key not configured', isError: true);
    } else {
      await DebugLogger.log('API_KEY_FOUND', details: 'API key configured (${apiKey.substring(0, min(8, apiKey.length))}...)');
    }

    final xpKeywordsStr = prefs.getString('xpKeywords') ?? 'xp,XP,Xp,xP';
    final xpKeywords = xpKeywordsStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (xpKeywords.isEmpty) {
      _log('⚠️ No XP keywords configured, using defaults');
      xpKeywords.addAll(['xp', 'XP', 'Xp', 'xP']);
    }

    final startDateStr = prefs.getString('startDate');
    DateTime? startDate;
    if (startDateStr != null) {
      startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) {
        _log('⚠️ Invalid startDate format: $startDateStr');
      }
    }

    final baseXP = prefs.getDouble('baseXP') ?? 400;
    final multiplier = prefs.getDouble('levelMultiplier') ?? 100;
    final exponent = prefs.getDouble('levelExponent') ?? 1.05;

    _log('⚙️ Loaded settings: keywords=$xpKeywords, startDate=$startDate, baseXP=$baseXP');

    // 🔹 Load cached tasks with error handling
    List<Map<String, dynamic>> cachedTasks = [];
    try {
      cachedTasks = await _loadCachedTasks();
      _log('📂 Loaded ${cachedTasks.length} cached tasks');
    } catch (e) {
      _log('⚠️ Failed to load cache: $e');
    }

    // 🔹 Fetch fresh tasks from Todoist with retry logic
    List<Map<String, dynamic>> fetchedTasks = [];
    if (apiKey.isNotEmpty) {
      fetchedTasks = await _fetchTasksWithRetry(apiKey, maxRetries: 3);
      _log('📡 Fetched ${fetchedTasks.length} from API');
    } else {
      _log('ℹ️ Skipping Todoist fetch (no API key)');
    }

    await prefs.setString('lastSync', DateTime.now().toUtc().toIso8601String());

    // 🔹 Merge fetched with cached (deduplicates by completed_at)
    List<Map<String, dynamic>> allTasks = [];
    try {
      allTasks = _mergeTasks(fetchedTasks, cachedTasks);
      _log('🔀 Merged to ${allTasks.length} total unique tasks');

      // 🔹 Save merged tasks back to cache
      await _saveCachedTasks(allTasks);
    } catch (e) {
      _log('⚠️ Cache merge failed, using fetched tasks only: $e');
      allTasks = fetchedTasks;
    }

    // 🔹 Filter completed tasks since start date
    final recentTasks = _filterTasksByDate(allTasks, startDate);

    // 🔹 Sort by completion time (newest first)
    recentTasks.sort((a, b) {
      final aTime = _parseDateTime(a['completed_at']) ?? DateTime(1970);
      final bTime = _parseDateTime(b['completed_at']) ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // 🔹 Calculate XP from tasks
    final xpResult = _calculateXP(recentTasks, xpKeywords);
    final taskXP = xpResult['totalXP'] as double;
    final recentChanges = xpResult['recentChanges'] as List<Map<String, dynamic>>;

    // 🔹 Load Starting XP offset and add to task XP
    final startingXP = prefs.getInt('startingXP') ?? 0;
    final totalXP = (startingXP.toDouble()) + taskXP;
    _log('💎 Total XP: ${totalXP.toInt()} (Starting: $startingXP + Tasks: ${taskXP.toInt()})');

    // 🔹 Compute levels
    final level = _computeLevel(totalXP, baseXP, multiplier, exponent);
    final xpInLevel = totalXP - _xpForLevel(level, baseXP, multiplier, exponent);
    final xpNeeded = _xpForLevel(level + 1, baseXP, multiplier, exponent) -
        _xpForLevel(level, baseXP, multiplier, exponent);

    // Validate level calculation
    if (level < 0) {
      _log('⚠️ Calculated negative level: $level, setting to 0');
      final correctedLevel = 0;
      await _saveXPStats(prefs, correctedLevel, 0, xpNeeded.toInt(), totalXP.toInt());
    } else {
      await _saveXPStats(prefs, level, xpInLevel.toInt(), xpNeeded.toInt(), totalXP.toInt());

      // 🎉 Detect level-up and save timestamp
      if (level > previousLevel && previousLevel > 0) {
        _log('🎉 LEVEL UP! $previousLevel → $level');
        await prefs.setString('levelUpTime', DateTime.now().toIso8601String());
        await prefs.setInt('levelUpFrom', previousLevel);
        await prefs.setInt('levelUpTo', level);
      }
    }

    // 🔹 Merge & maintain rolling log (last 10) using JSON
    final last10 = await _mergeAndSaveRecentChanges(prefs, recentChanges);

    // Format recent last with cleaned task name and integer XP
    final lastRecent = last10.isNotEmpty
        ? _formatRecentTask(last10.first['xp'], last10.first['task'], xpKeywords)
        : '+0XP — No data';
    await prefs.setString('recentLast', lastRecent);

    await prefs.reload(); // 🔹 Ensure prefs are flushed to disk

    // 🔹 Update widget
    try {
      // Get level-up time for widget animation
      final levelUpTime = prefs.getString('levelUpTime') ?? '';

      await LifeQuestWidgetService.updateWidgetData(
        level: level < 0 ? 0 : level,
        xpInLevel: xpInLevel.toInt(),
        xpNeeded: xpNeeded.toInt(),
        totalXP: totalXP.toInt(),
        recentChanges: last10
            .map((e) => {
                  'xp': e['xp'].toString(),
                  'task': e['task'].toString(),
                })
            .toList(),
        recentLast: lastRecent,
        levelUpTime: levelUpTime,
      );
    } catch (e) {
      _log('⚠️ Failed to update widget: $e');
      // Don't throw - widget update failure shouldn't break the refresh
    }

    _log('✅ XP sync complete → Level $level, ${xpInLevel.toInt()}/${xpNeeded.toInt()} XP');
  }

  /// Fetch tasks from Todoist with retry logic
  Future<List<Map<String, dynamic>>> _fetchTasksWithRetry(
    String apiKey, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      attempt++;
      try {
        _log('📡 Fetching tasks from Todoist (attempt $attempt/$maxRetries)');
        await DebugLogger.log('API_CALL_START', details: 'Todoist attempt $attempt/$maxRetries');

        final apiStartTime = DateTime.now();
        final url = Uri.parse('https://api.todoist.com/sync/v9/completed/get_all?limit=200');
        final response = await http
            .get(url, headers: {'Authorization': 'Bearer $apiKey'})
            .timeout(const Duration(seconds: 10)); // Reduced from 30s to 10s for faster failure detection

        final apiDuration = DateTime.now().difference(apiStartTime).inMilliseconds;
        await DebugLogger.log('API_CALL_RESPONSE', details: 'Status ${response.statusCode} in ${apiDuration}ms');

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final items = data['items'];

            if (items == null) {
              _log('⚠️ Todoist response missing "items" field');
              return [];
            }

            if (items is! List) {
              _log('⚠️ Todoist "items" is not a list: ${items.runtimeType}');
              return [];
            }

            final tasks = items
                .map((e) => e as Map<String, dynamic>)
                .toList();

            _log('✅ Fetched ${tasks.length} completed tasks from Todoist');
            return tasks;
          } catch (e) {
            _log('❌ JSON parsing error: $e');
            throw Exception('Failed to parse Todoist response: $e');
          }
        } else if (response.statusCode == 401) {
          _log('❌ Todoist API authentication failed (401) - invalid API key');
          throw Exception('Invalid API key');
        } else if (response.statusCode == 403) {
          _log('❌ Todoist API forbidden (403) - check API key permissions');
          throw Exception('API key lacks required permissions');
        } else if (response.statusCode == 429) {
          final retryAfter = response.headers['retry-after'];
          final waitTime = retryAfter != null
              ? int.tryParse(retryAfter) ?? retryDelay.inSeconds
              : retryDelay.inSeconds * attempt;

          if (attempt < maxRetries) {
            _log('⚠️ Rate limited (429), waiting ${waitTime}s before retry');
            await Future.delayed(Duration(seconds: waitTime));
            continue;
          } else {
            throw Exception('Rate limited - too many requests');
          }
        } else {
          _log('❌ Todoist API error: ${response.statusCode} - ${response.body}');
          throw Exception('Todoist API error: ${response.statusCode}');
        }
      } on http.ClientException catch (e) {
        lastException = e;
        _log('⚠️ Network error (attempt $attempt/$maxRetries): $e');

        // Don't retry DNS failures - they won't fix themselves
        if (e.toString().contains('Failed host lookup')) {
          await DebugLogger.log('DNS_FAILURE', details: 'DNS lookup failed, not retrying', isError: true);
          rethrow;
        }

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      } on Exception catch (e) {
        // Don't retry on authentication/authorization errors
        if (e.toString().contains('Invalid API key') ||
            e.toString().contains('API key lacks')) {
          rethrow;
        }
        lastException = e;
        _log('⚠️ Error (attempt $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      } catch (e) {
        lastException = Exception(e.toString());
        _log('⚠️ Unexpected error (attempt $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }

    _log('❌ Failed to fetch tasks after $maxRetries attempts');
    throw lastException ?? Exception('Failed to fetch tasks');
  }

  /// Filter tasks by start date
  List<Map<String, dynamic>> _filterTasksByDate(
    List<Map<String, dynamic>> tasks,
    DateTime? startDate,
  ) {
    if (startDate == null) return tasks;

    return tasks.where((task) {
      final completedAtStr = task['completed_at'];
      if (completedAtStr == null) return false;

      final completedAt = _parseDateTime(completedAtStr);
      if (completedAt == null) {
        _log('⚠️ Could not parse completed_at: $completedAtStr');
        return false;
      }

      return completedAt.isAfter(startDate);
    }).toList();
  }

  /// Calculate XP from tasks
  Map<String, dynamic> _calculateXP(
    List<Map<String, dynamic>> tasks,
    List<String> xpKeywords,
  ) {
    double totalXP = 0;
    final recentChanges = <Map<String, dynamic>>[];

    // Escape keywords for regex (handle special regex characters)
    final escapedKeywords = xpKeywords.map((k) => RegExp.escape(k)).toList();
    final pattern = r'([+-]?\s*\d+)\s*(?:' + escapedKeywords.join('|') + r')\b';

    for (final task in tasks) {
      final content = (task['content'] ?? '').toString();
      if (content.isEmpty) continue;

      final completedAtStr = task['completed_at'] ?? '';
      final completedAt = _parseDateTime(completedAtStr) ?? DateTime.now();

      bool matched = false;
      for (final keyword in xpKeywords) {
        if (content.contains(keyword)) {
          try {
            final regex = RegExp(pattern, caseSensitive: false);
            final match = regex.firstMatch(content);

            if (match != null) {
              final xpStr = match.group(1)?.replaceAll(RegExp(r'\s+'), '') ?? '0';
              final xp = double.tryParse(xpStr) ?? 0;

              if (xp != 0) {
                totalXP += xp;
                recentChanges.add({
                  'xp': xp,
                  'task': content,
                  'completedAt': completedAt.toIso8601String()
                });
                matched = true;
                break;
              }
            }
          } catch (e) {
            _log('⚠️ Regex error for task "$content": $e');
          }
        }
      }
    }

    if (tasks.isNotEmpty && recentChanges.isEmpty) {
      _log('ℹ️ No XP found in ${tasks.length} tasks');
    }

    return {
      'totalXP': totalXP,
      'recentChanges': recentChanges,
    };
  }

  /// Merge recent changes with existing entries and save using JSON
  Future<List<Map<String, dynamic>>> _mergeAndSaveRecentChanges(
    SharedPreferences prefs,
    List<Map<String, dynamic>> newChanges,
  ) async {
    // Load existing entries using JSON
    List<Map<String, dynamic>> existingList = [];
    try {
      final existingJson = prefs.getString('recent') ?? '';
      if (existingJson.isNotEmpty) {
        // Try JSON first (new format)
        try {
          final decoded = jsonDecode(existingJson) as List;
          existingList = decoded
              .map((e) => e as Map<String, dynamic>)
              .toList();
        } catch (e) {
          // Fallback to old pipe-delimited format for migration
          _log('ℹ️ Migrating from old format to JSON');
          if (existingJson.contains('||')) {
            final parts = existingJson.split('||');
            existingList = parts.map((p) {
              final kv = p.split('|');
              return {
                'xp': kv.isNotEmpty ? double.tryParse(kv[0]) ?? 0 : 0,
                'task': kv.length > 1 ? kv[1] : '',
                'completedAt': kv.length > 2
                    ? kv[2]
                    : DateTime.now().toIso8601String()
              };
            }).toList();
          }
        }
      }
    } catch (e) {
      _log('⚠️ Error loading existing recent changes: $e');
    }

    // Add new entries, avoiding duplicates
    for (final change in newChanges) {
      final xp = change['xp'] as num;
      final task = change['task'] as String;
      final completedAt = change['completedAt'] as String;

      // Check for duplicates (same XP, task, and completion time)
      final isDuplicate = existingList.any((e) =>
          (e['xp'] as num).toDouble() == xp.toDouble() &&
          e['task'] == task &&
          e['completedAt'] == completedAt);

      if (!isDuplicate) {
        existingList.add({
          'xp': xp,
          'task': task,
          'completedAt': completedAt,
        });
      }
    }

    // Sort by completion time (newest first)
    existingList.sort((a, b) {
      final aTime = _parseDateTime(a['completedAt']?.toString()) ?? DateTime(1970);
      final bTime = _parseDateTime(b['completedAt']?.toString()) ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // Keep only last 10
    final last10 = existingList.take(10).toList();

    // Save using JSON
    try {
      final serialized = jsonEncode(last10);
      await prefs.setString('recent', serialized);
    } catch (e) {
      _log('❌ Failed to serialize recent changes: $e');
    }

    return last10;
  }

  /// Save XP stats to SharedPreferences
  Future<void> _saveXPStats(
    SharedPreferences prefs,
    int level,
    int xpInLevel,
    int xpNeeded,
    int totalXP,
  ) async {
    await prefs.setInt('level', level);
    await prefs.setInt('xpInLevel', xpInLevel);
    await prefs.setInt('xpNeeded', xpNeeded);
    await prefs.setInt('totalXP', totalXP);
  }

  /// Parse DateTime with error handling
  DateTime? _parseDateTime(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.tryParse(dateStr.toString());
    } catch (e) {
      _log('⚠️ DateTime parse error: $dateStr - $e');
      return null;
    }
  }

  /// XP required for reaching a given level
  double _xpForLevel(int level, double base, double mult, double exp) {
    if (level <= 0) return 0;
    return base * level + mult * pow(level, exp);
  }

  /// Determine level from total XP
  int _computeLevel(double totalXP, double base, double mult, double exp) {
    if (totalXP < 0) {
      _log('⚠️ Negative totalXP: $totalXP');
      return 0;
    }

    int level = 0;
    while (_xpForLevel(level + 1, base, mult, exp) <= totalXP) {
      level++;
      // Safety check to prevent infinite loop
      if (level > 1000) {
        _log('⚠️ Level calculation exceeded 1000, stopping');
        break;
      }
    }
    return level;
  }

  /// Format recent task string, removing redundant XP from task name and formatting XP as integer
  String _formatRecentTask(dynamic xp, dynamic task, List<String> xpKeywords) {
    // Convert XP to integer (remove .0)
    final xpValue = (xp is num) ? xp.toInt() : int.tryParse(xp.toString()) ?? 0;

    // Clean task name by removing XP patterns
    String taskName = task.toString();

    // Escape keywords for regex
    final escapedKeywords = xpKeywords.map((k) => RegExp.escape(k)).toList();

    // Pattern to match XP in task name (e.g., "+100xp", "+100 XP", "100xp", etc.)
    final xpPattern = r'[+-]?\s*\d+\s*(?:' + escapedKeywords.join('|') + r')\b';
    final regex = RegExp(xpPattern, caseSensitive: false);

    // Remove XP patterns from task name
    taskName = taskName.replaceAll(regex, '').trim();

    // Clean up any extra spaces or separators
    taskName = taskName.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Add + prefix only for positive values (negative values already have -)
    return '${xpValue >= 0 ? '+' : ''}${xpValue}XP — $taskName';
  }

  /// Logging helper
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] $message');
  }
}
