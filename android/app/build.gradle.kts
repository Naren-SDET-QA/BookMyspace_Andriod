import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps key injection (NEVER commit the real key).
// Resolution order:
//   1. GOOGLE_MAPS_ANDROID_API_KEY environment variable (CI),
//   2. googleMapsApiKey in android/local.properties or ~/.gradle/gradle.properties
//      (both git-ignored developer machines),
//   3. empty string -> the manifest ships an inert placeholder and the native
//      map shows Google's own "missing key" state instead of crashing.
val googleMapsApiKey: String by lazy {
    val fromEnv = System.getenv("GOOGLE_MAPS_ANDROID_API_KEY")
    if (!fromEnv.isNullOrBlank()) return@lazy fromEnv
    val props = Properties()
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { props.load(it) }
    }
    val userProps = Properties()
    val globalProps = File(System.getProperty("user.home"), ".gradle/gradle.properties")
    if (globalProps.exists()) {
        globalProps.inputStream().use { userProps.load(it) }
    }
    props.getProperty("googleMapsApiKey")?.trim()?.takeIf { it.isNotBlank() }
        ?: userProps.getProperty("googleMapsApiKey")?.trim()?.takeIf { it.isNotBlank() }
        ?: ""
}

android {
    namespace = "com.bookmyspace.bookmyspace"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bookmyspace.bookmyspace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Keep the native checkout dependency explicit because this Flutter
    // module does not import the repository-level Android version catalog.
    implementation("com.razorpay:checkout:1.6.40")

    // NotificationCompat / NotificationManagerCompat / ActivityCompat for the
    // Android push channel. Pinned to the same version the repository-level
    // catalog uses for coreKtx, but declared explicitly for the same reason as
    // above: android/ has its own Gradle build with no version catalog.
    implementation("androidx.core:core-ktx:1.15.0")
}
