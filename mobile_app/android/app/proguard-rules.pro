# Razorpay checkout.
#
# Razorpay resolves payment classes reflectively, so R8 strips what it cannot
# see referenced and checkout fails at runtime — typically as a blank sheet or
# an immediate error, only in release builds. These are Razorpay's documented
# rules.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# Play Core is referenced by Flutter's deferred-components support but is not
# on the classpath of an app that does not use it.
-dontwarn com.google.android.play.core.**
