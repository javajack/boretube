package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/** One TV write (contract: time, op, target, before, after, ok, source). `time` is epoch ms. */
@Serializable
data class JournalEntry(
    val time: Long,
    val op: String,
    val target: String,
    val before: String = "",
    val after: String = "",
    val ok: Boolean,
    /** agent | watchdog | rule */
    val source: String,
    /** Shell command that undoes this write, when there is one. */
    val undo: String? = null,
)

/**
 * Ring buffer of the newest [capacity] entries. [onChange] persists it (the
 * Android side writes a file); the buffer is thread-safe.
 */
class Journal(
    private val capacity: Int = 1000,
    initial: List<JournalEntry> = emptyList(),
    private val onChange: (Journal) -> Unit = {},
) {
    private val entries = ArrayDeque<JournalEntry>(capacity)

    init {
        initial.takeLast(capacity).forEach { entries.addLast(it) }
    }

    @Synchronized
    fun add(e: JournalEntry) {
        while (entries.size >= capacity) entries.removeFirst()
        entries.addLast(e)
        onChange(this)
    }

    @Synchronized
    fun since(epochMs: Long): List<JournalEntry> = entries.filter { it.time > epochMs }

    @Synchronized
    fun all(): List<JournalEntry> = entries.toList()

    val size: Int @Synchronized get() = entries.size

    @Synchronized
    fun toJson(): String = AgentJson.encodeToString(ListSerializer(JournalEntry.serializer()), entries.toList())

    companion object {
        fun parseEntries(text: String?): List<JournalEntry> =
            if (text.isNullOrBlank()) emptyList()
            else try {
                AgentJson.decodeFromString(ListSerializer(JournalEntry.serializer()), text)
            } catch (_: Exception) {
                emptyList()
            }
    }
}
