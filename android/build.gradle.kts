allprojects {
    repositories {
        google()
        mavenCentral()
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

    // Force every Android library plugin to compile against compileSdk 36.
    // Some plugins still ship compileSdk=34 while their transitive deps
    // (e.g. flutter_plugin_android_lifecycle) require 36, which otherwise
    // aborts CheckAarMetadata. This afterEvaluate MUST be registered before
    // the evaluationDependsOn(":app") block below — once the subprojects are
    // eagerly evaluated, Gradle refuses to attach a new afterEvaluate.
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
