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
/** Where the child's progress lives (the app's file, or memory in tests). */
interface ProgressRepo {
    fun load(): LearnState
    fun save(s: LearnState)
}

class ProgressStore(private val dir: File, private val name: String = NAME) : ProgressRepo {
    private val file get() = File(dir, name)
    private val backup get() = File(dir, "$name.bak")
    private val temp get() = File(dir, "$name.tmp")

    override fun load(): LearnState = read(file) ?: read(backup) ?: LearnState()

    /** Never throws (a full disk loses this save, not the app). */
    @Synchronized
    override fun save(s: LearnState) {
        runCatching {
            dir.mkdirs()
            java.io.FileOutputStream(temp).use { out ->
                out.write(JSON.encodeToString(LearnState.serializer(), s).toByteArray())
                out.fd.sync() // on disk before the rename, so a power cut can't leave it empty
            }
            if (file.exists()) {
                // Only a readable save becomes the backup: never rotate a broken file over a good one.
                if (read(file) != null) {
                    backup.delete()
                    file.renameTo(backup)
                } else {
                    file.delete()
                }
            }
            temp.renameTo(file)
        }
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
