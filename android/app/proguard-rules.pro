# Suppress R8/ProGuard warnings for missing Java compiler classes referenced by shaded code generator libraries (like AutoValue and JavaPoet)
-dontwarn javax.lang.model.**

# Suppress warnings for Google Play Core Split Install classes referenced by Flutter deferred components engine
-dontwarn com.google.android.play.core.**

# Keep Flutter Wrapper & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepattributes SourceFile,LineNumberTable

# Keep TensorFlow Lite core classes (they use JNI/native reflection)
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep MediaPipe core classes and prevent aggressive optimizations
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Keep all synthetic lambdas used by MediaPipe
-keepclassmembers class com.google.mediapipe.**$$ExternalSyntheticLambda* { *; }

# Prevent R8 from inlining or changing method signatures in MediaPipe
-keepclassmembers,allowoptimization class com.google.mediapipe.** { <methods>; }

# Keep Protobuf related classes
-keep class com.google.mediapipe.proto.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite { *; }
-dontwarn com.google.protobuf.**

# Keep Flogger (logging) classes
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**

# Required for lambda + MethodHandle resolution
-keepattributes InnerClasses,EnclosingMethod,Signature,RuntimeVisibleAnnotations,AnnotationDefault
