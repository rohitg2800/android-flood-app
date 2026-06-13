import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val useReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.equinox.flood"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }

    if (useReleaseKeystore) {
        val keystoreProperties = Properties()
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
        signingConfigs {
            create("release") {
                keyAlias      = keystoreProperties["keyAlias"]      as String
                keyPassword   = keystoreProperties["keyPassword"]   as String
                storeFile     = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.equinox.flood"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode   = 2
        versionName   = "1.1.0"
        multiDexEnabled = true
    }

    buildTypes {
        // ── DEBUG ──────────────────────────────────────────────────────────
        // ProfileInstaller fires on every cold debug launch and blocks boot
        // for 1-3 minutes trying to write a baseline profile that has ZERO
        // effect in debug (non-AOT JIT) mode.  Disable it completely here.
        debug {
            // Suppress the D/ProfileInstaller "Installing profile" stall.
            // The resValue bool is read by the custom InitializationProvider
            // below; AGP also uses it to skip profile compilation.
            resValue("bool", "enable_app_startup", "false")
        }

        // ── RELEASE ────────────────────────────────────────────────────────
        release {
            signingConfig = if (useReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("androidx.multidex:multidex:2.0.1")

    // ── Baseline Profile / ProfileInstaller ───────────────────────────────
    // Only include profileinstaller in release. In debug it fires on every
    // cold launch and stalls boot for 1-3 min with no benefit (debug is JIT,
    // not AOT — profiles do nothing).
    releaseImplementation("androidx.profileinstaller:profileinstaller:1.3.1")
}

flutter {
    source = "../.."
}
