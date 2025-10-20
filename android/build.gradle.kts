allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Ensure legacy plugins that don't declare an Android namespace still work with AGP 8+
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            val currentNs = namespace
            if (currentNs == null || currentNs.isEmpty()) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                val manifestPkg = if (manifestFile.exists()) {
                    val text = manifestFile.readText()
                    val match = Regex("package=\\\"([^\\\"]+)\\\"").find(text)
                    match?.groupValues?.getOrNull(1)
                } else null
                namespace = manifestPkg ?: "com.generated.${project.name.replace('-', '_')}"
            }

            // Align Java toolchain for Android library modules
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
}

// Force consistent JVM targets for all subprojects (plugins included)
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = JavaVersion.VERSION_11.toString()
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
