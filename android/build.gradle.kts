allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.configureEach {
        resolutionStrategy.force(
            "androidx.core:core:1.18.0",
            "androidx.core:core-ktx:1.18.0",
        )
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { extension ->
            if (extension is com.android.build.gradle.BaseExtension) {
                extension.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    tasks.configureEach {
        if (name.contains("strip") && name.contains("DebugSymbols")) {
            doFirst {
                outputs.files.files.forEach { dir ->
                    listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64").forEach { abi ->
                        java.io.File(dir, "lib/$abi").mkdirs()
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
