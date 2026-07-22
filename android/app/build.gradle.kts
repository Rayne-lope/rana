import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("keystore.properties")
    if (propertiesFile.exists()) propertiesFile.inputStream().use(::load)
}
fun signingValue(property: String, environment: String): String? =
    keystoreProperties.getProperty(property)?.takeIf(String::isNotBlank)
        ?: System.getenv(environment)?.takeIf(String::isNotBlank)

val releaseStoreFile = signingValue("storeFile", "RANA_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "RANA_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "RANA_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "RANA_KEY_PASSWORD")
val releaseSigningComplete = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { it != null }
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !releaseSigningComplete) {
    throw GradleException(
        "Rana release signing is not configured. Provide android/keystore.properties " +
            "or RANA_KEYSTORE_PATH, RANA_KEYSTORE_PASSWORD, RANA_KEY_ALIAS, " +
            "and RANA_KEY_PASSWORD. See docs/release-checklist.md."
    )
}

android {
    namespace = "com.rana.app.rana"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rana.app.rana"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningComplete) {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    val cameraxVersion = "1.3.4"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")
    implementation("androidx.heifwriter:heifwriter:1.0.0")
    testImplementation("junit:junit:4.13.2")
}
