plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.peter1323.premiere_tracker"
    // Android 36: lo exigen la app y el plugin file_picker (su dependencia
    // flutter_plugin_android_lifecycle compila con 36). El minSdk no cambia,
    // así que la compatibilidad con móviles antiguos es la misma.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (avisos) usa APIs de Java modernas
        // también en Android antiguos gracias al "desugaring".
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Identidad de la app en Android (la Play Store rechaza com.example.*).
        applicationId = "com.peter1323.premiere_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

    // Nombre del APK generado: Premiere-Tracker.apk (en vez de app-release.apk),
    // para que al compartirlo por Telegram o USB lleve un nombre reconocible.
    applicationVariants.all {
        outputs.all {
            (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
                .outputFileName = "Premiere-Tracker.apk"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Necesario por isCoreLibraryDesugaringEnabled (avisos de estreno)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
