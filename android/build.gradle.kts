buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Nota: Mantén la versión de gradle que ya tienes en tu proyecto
        // classpath("com.android.tools.build:gradle:7.3.0") 
        
        // Esta es la línea importante que debes añadir
        classpath("com.google.gms:google-services:4.3.15")
    }
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
