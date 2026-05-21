import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

fun requireKeyProperty(name: String): String {
    val value =
        keyProperties.getProperty(name)
            ?: keyProperties.getProperty("\uFEFF$name") // handle accidental UTF-8 BOM on first key
    return value?.trim()?.takeIf { it.isNotEmpty() }
        ?: throw GradleException("Missing `$name` in ${keyPropertiesFile.path}")
}

android {
    namespace = "kz.alga.homework_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = requireKeyProperty("keyAlias")
                keyPassword = requireKeyProperty("keyPassword")
                // Resolve from android/ root, not android/app/
                storeFile = rootProject.file(requireKeyProperty("storeFile"))
                storePassword = requireKeyProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "kz.alga.homework_ai"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Do not fall back to the debug keystore for Play releases.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
