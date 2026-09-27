-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# ML Kit instantiates its components by reflection; keep them intact.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
