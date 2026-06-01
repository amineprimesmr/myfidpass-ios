# Retrofit + OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepattributes Signature
-keepattributes *Annotation*

# Kotlin serialization
-keepattributes InnerClasses
-keepclassmembers class kotlinx.serialization.json.** { *; }
-keepclassmembers class *$$serializer { *; }
-keep,includedescriptorclasses class fr.myfidpass.data.dto.**$$serializer { *; }
-keepclassmembers class fr.myfidpass.data.dto.** {
    *** Companion;
}
-if class fr.myfidpass.data.dto.**
-keepclassmembers class <1> {
    static **$Companion Companion;
}

# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.room.paging.**

# Firebase / FCM
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# ML Kit / CameraX
-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**

# Coil
-dontwarn coil.**

# Osmdroid
-dontwarn org.osmdroid.**

# Keep application entry points
-keep class fr.myfidpass.MyFidpassApplication { *; }
-keep class fr.myfidpass.MainActivity { *; }
-keep class fr.myfidpass.services.notifications.MyFidpassFirebaseMessagingService { *; }
