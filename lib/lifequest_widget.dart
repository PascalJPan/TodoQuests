import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class LifeQuestWidgetService {
  static const String widgetName = 'LifeQuestWidgetProvider';
  static const String androidWidget = 'LifeQuestWidgetProvider';

  /// Call this when XP or level updates.
  static Future<void> updateWidgetData({
    required int level,
    required int xpInLevel,
    required int xpNeeded,
    required int totalXP,
    required List<Map<String, dynamic>> recentChanges,
    required String recentLast,
    String? levelUpTime,
  }) async {
    print('🔧 [WIDGET_UPDATE_START] Updating widget data: Level=$level, XP=$xpInLevel/$xpNeeded');

    await HomeWidget.saveWidgetData<int>('level', level);
    await HomeWidget.saveWidgetData<int>('xpInLevel', xpInLevel);
    await HomeWidget.saveWidgetData<int>('xpNeeded', xpNeeded);
    await HomeWidget.saveWidgetData<int>('totalXP', totalXP);

    print('🔧 [WIDGET_DATA_SAVED] Saved level, xpInLevel, xpNeeded, totalXP');

    // Save milestone levels from settings so widget can read them
    final prefs = await SharedPreferences.getInstance();
    final milestoneLevels = prefs.getString('milestoneLevels') ?? '10,20,30,40,50';
    await HomeWidget.saveWidgetData<String>('milestoneLevels', milestoneLevels);

    // Store last few recent XP gains (using JSON for safety)
    final recentJson = recentChanges.map((e) => {
      'xp': e['xp'].toString(),
      'task': e['task'].toString(),
    }).toList();
    await HomeWidget.saveWidgetData<String>('recent', jsonEncode(recentJson));

    // Store recentLast for quick display in widget
    await HomeWidget.saveWidgetData<String>('recentLast', recentLast);

    // Store level-up time for celebration effect
    if (levelUpTime != null && levelUpTime.isNotEmpty) {
      await HomeWidget.saveWidgetData<String>('levelUpTime', levelUpTime);
    }

    // Set up click action to refresh XP
    await HomeWidget.saveWidgetData<String>('action', 'refresh');

    print('🔧 [WIDGET_DATA_COMPLETE] All data saved, triggering widget update');

    final updateResult = await HomeWidget.updateWidget(
      name: androidWidget,
      iOSName: widgetName,
      qualifiedAndroidName: 'com.example.life_quests.LifeQuestWidgetProvider',
    );

    print('🔧 [WIDGET_UPDATE_RESULT] Update result: $updateResult');
  }
}
