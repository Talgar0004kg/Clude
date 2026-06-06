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

// Register the namespace-injection hook BEFORE evaluationDependsOn(":app")
// triggers project evaluation, otherwise afterEvaluate fails with
// "Cannot run Project.afterEvaluate(Action) when the project is already evaluated".
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                val getNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                val setNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                val currentNamespace = getNamespace?.invoke(androidExt) as? String
                if (currentNamespace.isNullOrBlank() && setNamespace != null) {
                    val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val match = Regex("package=\"([^\"]+)\"").find(manifestFile.readText())
                        if (match != null) {
                            setNamespace.invoke(androidExt, match.groupValues[1])
                        }
                    }
                }
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
