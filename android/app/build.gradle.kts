import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "org.resqapp.donor"
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
        applicationId = "org.resqapp.donor"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release builds are signed with the shared ResQ key so an APK from any
    // machine installs over another. android/key.properties and the .jks it
    // points at are gitignored and shared privately. Without them, release
    // builds fall back to this machine's debug key.
    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

// Match compileOptions above. Without this Kotlin targets whatever JDK runs
// Gradle (e.g. 25 from Android Studio) and the build fails on the mismatch.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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