plugins {
    id("com.android.application")
    kotlin("android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.1")) // Use your chosen BoM version or latest stable
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-database")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Or latest stable
}

android {
    namespace = "com.example.mvc1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Ensure this is still correct/needed for your setup

    // Consolidated and corrected compileOptions
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11 // Using Java 11
        targetCompatibility = JavaVersion.VERSION_11 // Using Java 11
    }

    // Consolidated and corrected kotlinOptions
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() // Matching Java 11
    }

    defaultConfig {
        applicationId = "com.example.mvc1"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}