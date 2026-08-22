# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# flutter_map / latlong2
-keep class com.jakewharton.** { *; }

# Preserve annotations
-keepattributes *Annotation*

# Keep source file names and line numbers for crash reports
-keepattributes SourceFile,LineNumberTable

# Google Play Core (Flutter embedder references, not actually used)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
