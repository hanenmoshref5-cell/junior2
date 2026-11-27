plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.testttt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.testttt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}

dependencies {
    // AndroidX - AppCompat
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core:1.12.0")

    // AndroidX - Constraint Layout
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")

    // CameraX
    implementation("androidx.camera:camera-core:1.2.0")
    implementation("androidx.camera:camera-camera2:1.2.0")
    implementation("androidx.camera:camera-lifecycle:1.2.0")
    implementation("androidx.camera:camera-view:1.2.0")
    implementation("androidx.camera:camera-video:1.2.0")

    // Material Design
    implementation("com.google.android.material:material:1.9.0")

    // MPAndroidChart
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")

    // Guava (for ListenableFuture)
    implementation("com.google.guava:guava:32.0.1-android")

    // Lifecycle (required by CameraX)
    implementation("androidx.lifecycle:lifecycle-runtime:2.6.1")
    // Required for core library desugaring (for some plugins like flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.1.5")
}
