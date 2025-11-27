plugins {
    // We apply the rootproject plugin here directly.
    // The version is technically ignored because of includeBuild in settings.gradle.kts, but KTS syntax often requires it.
    id("com.facebook.react.rootproject") version "0.77.3"
}
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}
