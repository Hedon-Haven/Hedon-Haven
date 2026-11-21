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
}
subprojects {
    // rhttp 0.18.0 cargokit cannot parse "android-37.0", force an integer SDK for this module only
    plugins.withId("com.android.library") {
        if (name == "rhttp") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { it.compileSdk = 36 }
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

// Suppress JVM/kotlin task target compatibility build error
gradle.projectsEvaluated {
    mapOf(
        ":flutter_js" to org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
        ":receive_sharing_intent" to org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
        ":auto_orientation_v2" to org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
    ).forEach { (path, target) ->
        project(path) {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(target)
                }
            }
        }
    }
}