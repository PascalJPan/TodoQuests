import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_logger.dart';
import 'dart:convert';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> recentChanges = [];
  List<Map<String, dynamic>> debugLogs = [];
  int level = 1;
  int totalXP = 0;
  bool loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await DebugLogger.getLogs();

    setState(() {
      level = prefs.getInt('level') ?? 1;
      totalXP = prefs.getInt('totalXP') ?? 0;
      debugLogs = logs.reversed.toList(); // Show newest first

      // Parse 'recent' field - try JSON first (new format), fallback to old format
      final recentStr = prefs.getString('recent') ?? '';
      recentChanges = [];

      if (recentStr.isNotEmpty) {
        try {
          // Try JSON format first
          final decoded = jsonDecode(recentStr);
          if (decoded is List) {
            recentChanges = decoded
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        } catch (e) {
          // Fallback to old pipe-delimited format for migration
          if (recentStr.contains('||')) {
            final parts = recentStr.split('||');
            recentChanges = parts.map((p) {
              final kv = p.split('|');
              return {
                'xp': kv.isNotEmpty ? (double.tryParse(kv[0]) ?? 0) : 0,
                'task': kv.length > 1 ? kv[1] : '',
                'completedAt': kv.length > 2
                    ? kv[2]
                    : DateTime.now().toIso8601String()
              };
            }).toList();
          } else if (recentStr.contains('|')) {
            final kv = recentStr.split('|');
            recentChanges = [
              {
                'xp': kv.isNotEmpty ? (double.tryParse(kv[0]) ?? 0) : 0,
                'task': kv.length > 1 ? kv[1] : recentStr,
                'completedAt': kv.length > 2
                    ? kv[2]
                    : DateTime.now().toIso8601String()
              }
            ];
          }
        }
      }

      // Sort by completion time (newest first) to ensure correct order
      recentChanges.sort((a, b) {
        final aTime = DateTime.tryParse(a['completedAt']?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['completedAt']?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoQuests Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Debug Logs'),
                  content: const Text('Are you sure you want to clear all debug logs?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DebugLogger.clearLogs();
                await _loadLogs();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'XP Activity'),
            Tab(text: 'Debug Logs'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // XP Activity Tab
                _buildXPLogsTab(),
                // Debug Logs Tab
                _buildDebugLogsTab(),
              ],
            ),
    );
  }

  Widget _buildXPLogsTab() {
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Level $level — $totalXP total XP',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const Divider(),
          if (recentChanges.isEmpty)
            const Text('No recent XP activity yet.',
                style: TextStyle(color: Colors.grey))
          else
            ...recentChanges.map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(e['task']),
                    subtitle: Text('+${e['xp']} XP'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDebugLogsTab() {
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Diagnostic Events (${debugLogs.length})',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Shows widget clicks, background refreshes, and errors',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Divider(),
          if (debugLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No debug logs yet. Click the widget to test!',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...debugLogs.map((log) {
              final isError = log['isError'] == true;
              final event = log['event'] as String? ?? 'UNKNOWN';
              final details = log['details'] as String?;
              final timestamp = log['timestamp'] as String?;
              final timeAgo = timestamp != null
                  ? DebugLogger.formatTimestamp(timestamp)
                  : 'unknown time';

              return Card(
                color: isError
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.05),
                child: ListTile(
                  leading: Icon(
                    isError ? Icons.error_outline : Icons.info_outline,
                    color: isError ? Colors.red : Colors.blue,
                  ),
                  title: Text(
                    event,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isError ? Colors.red : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (details != null) ...[
                        const SizedBox(height: 4),
                        Text(details),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  isThreeLine: details != null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
