package com.example.life_quests

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class LifeQuestWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d("LifeQuestWidgetProvider", "📥 onReceive: ${intent.action}")

        // Handle widget update action - get all widget IDs if not provided
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                ?: appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, LifeQuestWidgetProvider::class.java))
            if (appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("LifeQuestWidgetProvider", "✅ onUpdate triggered for ${appWidgetIds.size} widgets")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lifequest_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            val level = prefs.getInt("level", 1)
            val xpInLevel = prefs.getInt("xpInLevel", 0)
            val xpNeeded = prefs.getInt("xpNeeded", 100)
            val recent = prefs.getString("recentLast", "+0XP — No data")

            // Check for milestone levels from Flutter SharedPreferences
            // Flutter uses "flutter." prefix for keys, but home_widget plugin handles this automatically
            val milestoneStr = prefs.getString("milestoneLevels", "10,20,30,40,50")
            val milestoneLevels = milestoneStr?.split(",")?.mapNotNull { it.trim().toIntOrNull() } ?: listOf(10, 20, 30, 40, 50)
            val isMilestoneLevel = milestoneLevels.contains(level)

            Log.d("LifeQuestWidgetProvider", "🏆 Milestone check: level=$level, milestoneStr='$milestoneStr', isMilestone=$isMilestoneLevel")

            // Check for recent level-up (within last 5 seconds)
            val levelUpTimeStr = prefs.getString("levelUpTime", null)
            val isLevelUp = levelUpTimeStr?.let { timeStr ->
                try {
                    val levelUpTime = java.time.Instant.parse(timeStr)
                    val now = java.time.Instant.now()
                    val secondsSinceLevelUp = java.time.Duration.between(levelUpTime, now).seconds
                    secondsSinceLevelUp < 5
                } catch (e: Exception) {
                    false
                }
            } ?: false

            // Calculate progress percentage (0-100)
            val progressPercent = if (xpNeeded > 0) {
                ((xpInLevel.toFloat() / xpNeeded.toFloat()) * 100).toInt()
            } else {
                0
            }

            // Parse recent into XP and task name
            val recentParts = recent?.split(" — ", limit = 2) ?: listOf("+0XP", "No data")
            val recentXP = recentParts.getOrNull(0) ?: "+0XP"
            val recentTask = recentParts.getOrNull(1) ?: "No data"

            Log.d("LifeQuestWidgetProvider", "📊 Widget data: Level=$level, XP=$xpInLevel/$xpNeeded ($progressPercent%), Recent=$recent, Milestone=$isMilestoneLevel, LevelUp=$isLevelUp")

            // 🔹 Set background: gold only for recent level-up (not for milestones)
            val backgroundDrawable = if (isLevelUp) {
                R.drawable.widget_levelup_background
            } else {
                R.drawable.widget_normal_background
            }
            views.setInt(R.id.widgetRoot, "setBackgroundResource", backgroundDrawable)

            // 🔹 Update widget text (add trophy emoji for milestone levels)
            val levelText = if (isMilestoneLevel) {
                "Level $level 🏆"
            } else {
                "Level $level"
            }
            views.setTextViewText(R.id.txtLevel, levelText)
            views.setTextViewText(R.id.txtProgress, "$xpInLevel / $xpNeeded XP")
            views.setTextViewText(R.id.txtRecentXP, recentXP)
            views.setTextViewText(R.id.txtRecentTask, recentTask)
            views.setProgressBar(R.id.progressBar, 100, progressPercent, false)

            // 🔹 On-click: trigger background refresh WITHOUT opening the app
            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("lifequest://refresh")
            )

            views.setOnClickPendingIntent(R.id.widgetRoot, backgroundIntent)

            Log.d("LifeQuestWidgetProvider", "✅ Widget click handler set to trigger background refresh (no app opening)")
            Log.d("LifeQuestWidgetProvider", "🔗 Background intent URI: lifequest://refresh")

            // 🔹 Apply widget update
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
