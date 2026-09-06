# ProGuard & R8 Optimization and Obfuscation Configuration for BookMySpace

# Optimization Settings
-repackageclasses 'com.bookmyspace.bookmyspace.obf'
-allowaccessmodification
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Keep Line Numbers & Source Files for Clean Stacktraces
-keepattributes SourceFile,LineNumberTable,EnclosingMethod,InnerClasses,Signature,*Annotation*

# ===================================================================
# Application Data Models & Serialized Classes
# ===================================================================
-keep class com.bookmyspace.bookmyspace.data.model.** { *; }
-keepclassmembers class com.bookmyspace.bookmyspace.data.model.** { *; }
-keep class com.bookmyspace.bookmyspace.data.invoice.** { *; }

# ===================================================================
# Firebase Services (Auth, Firestore, Messaging, Analytics)
# ===================================================================
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keepattributes *Annotation*,Signature

# Firebase Firestore Serialization / Deserialization
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
    @com.google.firebase.firestore.Exclude <fields>;
    @com.google.firebase.firestore.Exclude <methods>;
    @com.google.firebase.firestore.ServerTimestamp <fields>;
}
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**

# Firebase Messaging (FCM)
-keep class com.bookmyspace.bookmyspace.data.notification.BookMySpaceFirebaseMessagingService { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# Google Play Services & Identity / Credentials
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# ===================================================================
# AndroidX Room Database
# ===================================================================
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public abstract <methods>;
}

# ===================================================================
# Kotlin Coroutines & Flow
# ===================================================================
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-dontwarn kotlinx.coroutines.**

# ===================================================================
# Jetpack Compose & Navigation
# ===================================================================
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**
-keep class androidx.navigation.** { *; }
-dontwarn androidx.navigation.**

# ===================================================================
# JSON & Serialization (kotlinx.serialization / Org.json)
# ===================================================================
-keepattributes *Annotation*,EnclosingMethod,InnerClasses,Signature
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**
-keepclassmembers class * {
    @kotlinx.serialization.Serializable <fields>;
    @kotlinx.serialization.SerialName <fields>;
}

# ===================================================================
# Strip Log Messages in Release Builds (Optional performance boost)
# ===================================================================
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}
