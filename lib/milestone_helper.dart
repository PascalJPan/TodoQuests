import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MilestoneHelper {
  /// Get milestone levels from settings
  static Future<List<int>> getMilestoneLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final milestoneStr = prefs.getString('milestoneLevels') ?? '10,20,30,40,50';

    return milestoneStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .where((level) => level > 0)
        .toList()
      ..sort();
  }

  /// Check if current level is a milestone
  static Future<bool> isMilestone(int level) async {
    final milestones = await getMilestoneLevels();
    return milestones.contains(level);
  }

  /// Get the next milestone level
  static Future<int?> getNextMilestone(int currentLevel) async {
    final milestones = await getMilestoneLevels();
    for (final milestone in milestones) {
      if (milestone > currentLevel) {
        return milestone;
      }
    }
    return null;
  }

  /// Get milestone color (simple gold for all milestones)
  static List<Color> getMilestoneColors(int level) {
    // Simple gold color for all milestone levels
    return [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFFD700), // Gold
    ];
  }

  /// Get primary milestone color
  static Color getMilestonePrimaryColor(int level) {
    return const Color(0xFFFFD700); // Gold
  }
}

