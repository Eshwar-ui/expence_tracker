import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Task to patch flutter_notification_listener AndroidManifest.xml
tasks.register("patchNotificationListenerManifest") {
    doLast {
        val localAppData = System.getenv("LOCALAPPDATA")
        val manifestPath = "$localAppData\\Pub\\Cache\\hosted\\pub.dev\\flutter_notification_listener-1.3.4\\android\\src\\main\\AndroidManifest.xml"
        val manifestFile = File(manifestPath)
        
        if (manifestFile.exists()) {
            val content = manifestFile.readText()
            if (content.contains("package=\"im.zoe.labs.flutter_notification_listener\"")) {
                println("Patching flutter_notification_listener AndroidManifest.xml")
                val patched = content.replace(
                    Regex("""package="im\.zoe\.labs\.flutter_notification_listener"\s*"""),
                    ""
                )
                manifestFile.writeText(patched)
                println("Successfully patched flutter_notification_listener AndroidManifest.xml")
            } else {
                println("flutter_notification_listener AndroidManifest.xml already patched")
            }
        } else {
            println("flutter_notification_listener AndroidManifest.xml not found at $manifestPath")
        }
    }
}

// Run the patch before preBuild
tasks.named("preBuild") {
    dependsOn("patchNotificationListenerManifest")
}

android {
    namespace = "com.eshwar.expensetracker"
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
        applicationId = "com.eshwar.expensetracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Load keystore properties
    val keystorePropertiesFile = rootProject.file("key.properties")
    
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val props = Properties()
                FileInputStream(keystorePropertiesFile).use { props.load(it) }
                
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
