import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load debug keystore properties
val keystorePropertiesDebug = Properties()
val keystorePropertiesFileDebug = rootProject.file("keystores/debug.properties")
if (keystorePropertiesFileDebug.exists()) {
    keystorePropertiesDebug.load(FileInputStream(keystorePropertiesFileDebug))
}

// Load release keystore properties
val keystorePropertiesRelease = Properties()
val keystorePropertiesFileRelease = rootProject.file("keystores/release.properties")
if (keystorePropertiesFileRelease.exists()) {
    keystorePropertiesRelease.load(FileInputStream(keystorePropertiesFileRelease))
}

android {
    namespace = "com.hedon_haven.viewer"
    compileSdk = 37 // flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hedon_haven.viewer"
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

    signingConfigs {
        getByName("debug") {
            keyAlias = keystorePropertiesDebug["keyAlias"] as String?
            keyPassword = keystorePropertiesDebug["keyPassword"] as String?
            storeFile = keystorePropertiesDebug["storeFile"]?.let { file(it as String) }
            storePassword = keystorePropertiesDebug["storePassword"] as String?
        }
        create("release") {
            keyAlias = keystorePropertiesRelease["keyAlias"] as String?
            keyPassword = keystorePropertiesRelease["keyPassword"] as String?
            storeFile = keystorePropertiesRelease["storeFile"]?.let { file(it as String) }
            storePassword = keystorePropertiesRelease["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appName"] = "Hedon Haven debug"
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            manifestPlaceholders["appName"] = "Hedon Haven"
        }
        getByName("profile") {
            // FIXME: The line below errors out with:
            //  "Library projects cannot set applicationIdSuffix. applicationIdSuffix is set to '.profile' in build type 'profile'."
            //  yet for some reason the build types above (debug and release) still work
            // applicationIdSuffix = ".profile"
            manifestPlaceholders["appName"] = "Hedon Haven profile"
        }
    }

    // Disable Google's encrypted dependency metadata blob
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
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
