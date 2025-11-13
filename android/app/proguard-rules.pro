# Keep home_widget plugin classes to prevent tree-shaking
-keep class es.antonborri.home_widget.** { *; }
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker

# Keep the background receiver for widget interactions
-keep class * extends android.appwidget.AppWidgetProvider { *; }
-keep class * extends android.content.BroadcastReceiver { *; }

# Keep LifeQuest widget provider
-keep class com.example.life_quests.LifeQuestWidgetProvider { *; }

# Prevent obfuscation of callback methods
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}

# Keep WorkManager initialization
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
