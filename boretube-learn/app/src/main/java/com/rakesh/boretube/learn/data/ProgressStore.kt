package com.rakesh.boretube.learn.data

import com.rakesh.boretube.learn.core.LearnState
import kotlinx.serialization.json.Json
import java.io.File

/**
 * The child's progress as `progress.json` in [dir]. Saves are atomic (write a
 * temp file, keep the previous file as `.bak`, rename), so a power cut mid-save
 * loses at most the last level. Loading falls back to the backup, then to
 * empty progress; it never throws.
 */
class ProgressStore(private val dir: File) {
    private val file get() = File(dir, NAME)
    private val backup get() = File(dir, "$NAME.bak")
    private val temp get() = File(dir, "$NAME.tmp")

    fun load(): LearnState = read(file) ?: read(backup) ?: LearnState()

    @Synchronized
    fun save(s: LearnState) {
        dir.mkdirs()
        temp.writeText(JSON.encodeToString(LearnState.serializer(), s))
        if (file.exists()) {
            backup.delete()
            file.renameTo(backup)
        }
        temp.renameTo(file)
    }

    private fun read(f: File): LearnState? = try {
        if (!f.exists()) null else JSON.decodeFromString(LearnState.serializer(), f.readText())
    } catch (_: Exception) {
        null
    }

    companion object {
        const val NAME = "progress.json"
        private val JSON = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    }
}
