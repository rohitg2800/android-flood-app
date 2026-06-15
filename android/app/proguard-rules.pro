# OpsFlood — Production ProGuard / R8 rules
# Phase 2 Stability + Phase 4 Release Hardening
# ============================================================

# ── Flutter engine ──────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Firebase ───────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Messaging (FCM) ───────────────────────────────────────────────
-keep class com.google.firebase.messaging.** { *; }

# ── Firebase Crashlytics ───────────────────────────────────────────────────
-keepattributes *Annotation*
-keep class com.crashlytics.** { *; }
-dontwarn com.crashlytics.**
-keep class com.google.firebase.crashlytics.** { *; }
# Preserve stack trace line numbers — CRITICAL for Crashlytics reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── WorkManager (background tasks) ──────────────────────────────────────────
-keep class androidx.work.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }
-dontwarn androidx.work.**
# Keep all Worker subclasses from being stripped
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# ── Hive (local DB) ─────────────────────────────────────────────────────────────
-keep class com.hivedb.** { *; }
-keep @com.hive.annotations.HiveType class * { *; }
-keep @com.hive.annotations.HiveField class * { *; }
# Hive flutter plugin
-keep class io.hive.** { *; }

# ── Kotlin coroutines / stdlib ───────────────────────────────────────────────
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keepclassmembers class kotlinx.** { *; }
-dontwarn kotlinx.coroutines.**

# ── OkHttp / Retrofit (used by Dio on Android) ─────────────────────────────
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Dio (HTTP client) ───────────────────────────────────────────────────────────
-keep class com.dio.** { *; }

# ── PDF / printing plugin (dart:ffi JNI bridge) ───────────────────────────
-keep class com.zynsoft.** { *; }
-keep class com.pdf.** { *; }

# ── flutter_local_notifications ───────────────────────────────────────────
-keep class com.dexterous.** { *; }

# ── Geolocator (uses platform channels + reflection) ──────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── google_mobile_ads (AdMob) ────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**

# ── home_widget (AppWidgetProvider) ──────────────────────────────────────
-keep class es.antonborri.home_widget.** { *; }
-keep class * extends android.appwidget.AppWidgetProvider { *; }

# ── Riverpod (pure Dart — no Java classes, but keep annotations) ────────────
-keepattributes *Annotation*

# ── Exception handling — CRITICAL: preserve custom exception class names ──────
-keep public class * extends java.lang.Exception
-keep public class * extends java.lang.RuntimeException

# ── JSON / serialisation ───────────────────────────────────────────────────
-keep class org.json.** { *; }

# ── Generic reflection safety ────────────────────────────────────────────
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
