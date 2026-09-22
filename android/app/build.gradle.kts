plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.resq"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (18.x) uses java.time APIs that need
        // desugaring to run on minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.resq"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// The google-services plugin hard-fails the whole build if
// google-services.json isn't present, so it's only applied once that file
// actually exists — download it from the Firebase project's Android app
// settings and drop it in this same android/app/ folder (see setup
// instructions) to turn push on. Until then the app builds and runs
// normally, just without push (PushService.init/registerDevice already
// catch Firebase's absence and no-op).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}