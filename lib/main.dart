import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import 'xp_service.dart';
import 'logs_page.dart';
import 'milestone_helper.dart';
import 'debug_logger.dart';

import 'package:home_widget/home_widget.dart';

// Mark as entry point to prevent tree-shaking in release builds
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // Initialize Flutter bindings for background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Set app group ID for widget communication (Android SharedPreferences / iOS App Groups)
  await HomeWidget.setAppGroupId('group.com.example.life_quests');

  final startTime = DateTime.now();

  print('🔍 [WIDGET_CLICK] URI: ${uri?.toString() ?? "null"}');

  if (uri == null) {
    print('❌ [CALLBACK_FAILED] URI is null');
    return;
  }

  if (uri.host == 'refresh' || uri.queryParameters['action'] == 'refresh') {
    print('🔄 [REFRESH_START] Widget clicked - triggering background XP refresh');

    try {
      // Refresh XP (this will also update the widget)
      await LifeQuestService().refreshXP();

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('✅ [REFRESH_SUCCESS] Background refresh completed in ${duration}ms');
      // Note: Widget is already updated by refreshXP(), no need to trigger again
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('❌ [REFRESH_ERROR] Failed after ${duration}ms: $e');
      // Don't throw - background callbacks shouldn't crash
    }
  } else {
    print('⚠️ [CALLBACK_IGNORED] URI does not match refresh pattern');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background callback for widget interactions
  print('📱 [APP_START] Registering background callback');
  await HomeWidget.registerInteractivityCallback(backgroundCallback);
  print('✅ [CALLBACK_REGISTERED] Background callback registered successfully');

  runApp(const LifeQuestApp());
}


class LifeQuestApp extends StatelessWidget {
  const LifeQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TodoQuests',
      theme: ThemeData.dark(useMaterial3: true),
      home: const LifeQuestHome(),
    );
  }
}

class LifeQuestHome extends StatefulWidget {
  const LifeQuestHome({super.key});

  @override
  State<LifeQuestHome> createState() => _LifeQuestHomeState();
}

class _LifeQuestHomeState extends State<LifeQuestHome> {
  int level = 1;
  int xpInLevel = 0;
  int xpNeeded = 100;
  String recent = '+0XP — No data';
  bool loading = true;
  bool _isRefreshing = false;
  bool _isMilestone = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupWidgetCommunication();
  }

  void _setupWidgetCommunication() {
    // Set app group ID for widget communication (Android SharedPreferences / iOS App Groups)
    HomeWidget.setAppGroupId('group.com.example.life_quests');
  }


  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentLevel = prefs.getInt('level') ?? 1;
    final isMilestoneLevel = await MilestoneHelper.isMilestone(currentLevel);

    setState(() {
      level = currentLevel;
      xpInLevel = prefs.getInt('xpInLevel') ?? 0;
      xpNeeded = prefs.getInt('xpNeeded') ?? 100;
      recent = prefs.getString('recentLast') ?? '+0XP — No data';
      _isMilestone = isMilestoneLevel;
      loading = false;
    });
  }


  /// Unified refresh method with UI-level debouncing
  Future<void> _refreshXP({bool silent = false}) async {
    // UI-level debouncing (service-level debouncing also exists)
    if (_isRefreshing) {
      print('🌀 Refresh already in progress, skipping');
      return;
    }

    _isRefreshing = true;
    print('🌀 RefreshXP triggered');

    try {
      await LifeQuestService().refreshXP();

      // Reload data after refresh
      await _loadData();

      // Ensure widget is updated
      await HomeWidget.updateWidget(
        name: 'LifeQuestWidgetProvider',
        iOSName: 'LifeQuestWidgetProvider',
        qualifiedAndroidName: 'com.example.life_quests.LifeQuestWidgetProvider',
      );

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XP updated!')),
        );
      }
    } catch (e) {
      print('❌ Error refreshing XP: $e');
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing XP: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoQuests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsPage()),
              );
              // Refresh main page data when returning from logs
              if (mounted) {
                await _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              print('⚙️ Settings button pressed');
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );

              // Settings page already triggers refreshXP() when saved
              // Just reload data to reflect any changes
              if (changed == true) {
                print('✅ Settings changed — reloading data');
                await _loadData();
              } else {
                print('ℹ️ Settings not changed');
              }
            },
          ),


        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshXP,
              child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_isMilestone) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events,
                                color: Colors.amber, size: 32),
                            const SizedBox(width: 12),
                            Text(
                              'Level $level',
                              style: Theme.of(context)
                                  .textTheme.headlineMedium
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.emoji_events,
                                color: Colors.amber, size: 32),
                          ],
                        ),
                      ),
                    ] else
                      Text(
                        'Level $level',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    const SizedBox(height: 10),
                    Text('XP: $xpInLevel / $xpNeeded'),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: xpInLevel / xpNeeded,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 30),
                    Text('Recent: $recent'),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _isRefreshing ? null : _refreshXP,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh XP'),
                    ),
                  ],
                ),
              ),
    );
  }
}
