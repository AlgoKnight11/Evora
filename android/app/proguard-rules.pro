# Flutter Wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# EVORA Native Application & MainActivity
-keep class com.evora.app.** { *; }

# Google Play Services & Play Integrity
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Firebase SDKs (Auth, Firestore, Core, App Check)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Sign-In & Credentials
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.libraries.identity.googleid.**

# Cloudinary & OkHttp (if used by plugins)
-keep class com.cloudinary.** { *; }
-dontwarn com.cloudinary.**
-dontwarn okio.**
-dontwarn okhttp3.**

# Keep annotations & generic signatures for reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
