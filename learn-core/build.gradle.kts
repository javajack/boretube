plugins {
    kotlin("jvm") version "1.9.24"
    kotlin("plugin.serialization") version "1.9.24"
}

group = "com.rakesh.boretube"
version = "1.0"

repositories { mavenCentral() }

kotlin { jvmToolchain(17) }

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    testImplementation("junit:junit:4.13.2")
}

tasks.test {
    // GenSkillsTest: -Pgen.subject=english limits it to one subject.
    systemProperty("gen.subject", (project.findProperty("gen.subject") as String?) ?: "")
    testLogging { showStandardStreams = true }
    (project.findProperty("jfr") as String?)?.let { jvmArgs("-XX:StartFlightRecording=filename=$it,settings=profile") }
}
