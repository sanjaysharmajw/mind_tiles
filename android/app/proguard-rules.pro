# Flutter / plugin classes are kept by their own consumer rules.
# Keep audioplayers' platform channel classes.
-keep class xyz.luan.audioplayers.** { *; }
# Play Core (deferred components) is referenced by the Flutter engine but not used.
-dontwarn com.google.android.play.core.**
