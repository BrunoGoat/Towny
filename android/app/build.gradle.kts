import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The one key every build of this app is signed with.
//
// Android will not install a build over one signed with a different key: it
// refuses the update, and the only way past it is to uninstall, which takes
// the person's town with it. So the key cannot be a new one each time, and for
// a while it was — the release build was signed with the *debug* key, and a
// fresh CI runner has no debug keystore, so Gradle made a new random one on
// every run and threw it away. Two consecutive builds had two different
// certificates and neither could update the other.
//
// The keystore is `android/towny.jks`, and it is committed — which is not
// where a signing key normally lives. It is here on purpose: the app is not
// published anywhere, so there is no installed copy of anybody's that somebody
// holding this key could replace, and in exchange a clone of this repository
// builds an APK that installs over the last one and keeps the town, with no
// secret for anybody to paste anywhere. The day it is published this key gets
// replaced by one that is not in a repository, or by Play's own signing.
// `android/.gitignore` says the same thing, next to the exception that lets
// the file through.
//
// If the file is ever missing — somebody building from a copy without it —
// this falls back to the debug key, which is right for a build nobody is going
// to install over anything.
val keyProps = Properties()
val keyFile = rootProject.file("key.properties")
if (keyFile.exists()) {
    keyFile.inputStream().use { keyProps.load(it) }
}
val signedForReal = keyProps.getProperty("storeFile") != null

android {
    namespace = "com.towny.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo pide `flutter_local_notifications`: usa las clases de fecha y
        // hora de Java 8, que en Android 7 no existen, y el desugaring es lo
        // que las trae. Sin esto la APK no compila — y como la app sostiene
        // Android 7 a propósito, subir el mínimo no era una opción.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Esto es la identidad de la app para Android, y cambiarla no renombra
        // nada: crea otra. Decía `com.lamuralla.la_muralla`, de cuando esto se
        // llamaba La Muralla, y se cambió a sabiendas de que la build siguiente
        // se instala **al lado** de la anterior en vez de encima — con el valle
        // vacío, mientras la vieja se queda con los pueblos. Se pudo hacer
        // porque la app no está publicada y la única copia instalada es la de
        // quien la escribe, que sacó su copia antes.
        //
        // A partir de aquí vuelve a ser intocable, y por el mismo motivo de
        // siempre. El paquete de Kotlin y la clave de firma van con ésta.
        applicationId = "com.towny.app"
        // Flutter's default (API 24) already clears every plugin here, and
        // leaving the reference in place keeps `flutter build` from rewriting
        // this line into Groovy syntax inside a Kotlin script.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signedForReal) {
            create("towny") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signedForReal) {
                signingConfigs.getByName("towny")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
