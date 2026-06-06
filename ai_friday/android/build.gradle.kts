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
    project.evaluationDependsOn(":app")
}

// Workaround for discontinued plugins (e.g. contacts_service) that don't
// declare a namespace, which AGP 8+ requires. Reads `package` from the
// plugin's AndroidManifest.xml and applies it as the namespace.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                val getNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                val setNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
