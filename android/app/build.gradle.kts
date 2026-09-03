import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val requiredSigningProperties = listOf(
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile",
)

if (isReleaseBuild) {
    check(keyPropertiesFile.exists()) {
        "Android release signing is not configured. Copy android/key.properties.example to android/key.properties and add the upload-keystore credentials."
    }

    val missingProperties = requiredSigningProperties.filter { name ->
        keyProperties.getProperty(name).isNullOrBlank() ||
            keyProperties.getProperty(name).startsWith("REPLACE_WITH_")
    }
    check(missingProperties.isEmpty()) {
        "Android release signing properties are missing or still placeholders: ${missingProperties.joinToString()}"
    }

    val releaseKeystore = file(keyProperties.getProperty("storeFile"))
    check(releaseKeystore.isFile) {
        "Android upload keystore not found at ${releaseKeystore.absolutePath}"
    }
}

android {
    namespace = "com.parentpeak.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.parentpeak.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use release key when key.properties exists. Never sign release with debug key.
            if (keyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
