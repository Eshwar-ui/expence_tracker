# TensorFlow Lite ProGuard Rules
# Keep all TensorFlow Lite classes to prevent R8 from removing them

# Keep all TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Keep GpuDelegate and related classes
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep Interpreter and related classes
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.InterpreterApi { *; }
-keep class org.tensorflow.lite.InterpreterFactory { *; }

# Keep Tensor and related classes
-keep class org.tensorflow.lite.Tensor { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep classes that are referenced by native code
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Don't warn about missing classes (some may be optional)
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.nnapi.**
