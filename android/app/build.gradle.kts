plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartvest.smartvest"
    // The compileSdk is set by the Flutter Gradle Plugin.
    // You can override it here if you really need to.
    compileSdk = flutter.compileSdkVersion
    // It's recommended to let Flutter manage the NDK version,
    // but you can override it like this if necessary.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // This enables the use of modern Java language features on older Android API levels.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.smartvest.smartvest"
        // minSdk is set by the Flutter Gradle Plugin.
        // You can override it here if you really need to.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // This is the dependency for core library desugaring.
    // The version should be compatible with your Android Gradle Plugin version.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
