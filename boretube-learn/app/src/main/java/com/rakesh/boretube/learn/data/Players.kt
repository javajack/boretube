package com.rakesh.boretube.learn.data

import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/** A child who plays on this TV: their avatar (a picture id), class and language. */
@Serializable
data class Player(val id: String, val pic: String, val grade: Int, val lang: String = "en")

/** The children who share this install, and who is playing now. Each has their own progress. */
interface PlayersRepo {
    fun all(): List<Player>
    fun activeId(): String?
    fun setActive(id: String)
    /** Adds or updates [p]. */
    fun put(p: Player)
    fun progress(id: String): ProgressRepo
    /** Forgets [id] and their progress (never the last player). */
    fun remove(id: String)

    /** A new player's id. */
    fun newId(): String = "p" + ((all().mapNotNull { it.id.removePrefix("p").toIntOrNull() }.maxOrNull() ?: 0) + 1)

    fun active(): Player? = all().firstOrNull { it.id == activeId() } ?: all().firstOrNull()

    companion object {
        const val MAX = 6
        /** Avatars to choose from: friendly animals from the picture library. */
        val AVATARS = listOf("lion", "elephant", "peacock", "tiger", "panda", "monkey", "rabbit", "parrot", "giraffe", "penguin", "owl", "turtle")
    }
}

/**
 * Players in SharedPreferences; progress files in [dir]. The first player
 * keeps `progress.json` (so the one child from before players existed keeps
 * everything); later players get `progress-<id>.json`.
 */
class PlayersStore(private val prefs: SharedPreferences, private val dir: File) : PlayersRepo {
    override fun all(): List<Player> {
        val raw = prefs.getString(K_PLAYERS, null)
        val list = raw?.let { runCatching { JSON.decodeFromString(ListSerializer(Player.serializer()), it) }.getOrNull() }.orEmpty()
        if (list.isNotEmpty() || !prefs.getBoolean("set", false)) return list
        // Before players: the one child chose a class and language on first run.
        val first = Player("p1", AVATAR_FIRST, prefs.getInt("grade", 1).coerceIn(0, 7), prefs.getString("lang", "en") ?: "en")
        save(listOf(first))
        return listOf(first)
    }

    override fun activeId(): String? = prefs.getString(K_ACTIVE, null) ?: all().firstOrNull()?.id

    override fun setActive(id: String) { prefs.edit().putString(K_ACTIVE, id).apply() }

    override fun put(p: Player) {
        val list = all()
        save(if (list.any { it.id == p.id }) list.map { if (it.id == p.id) p else it } else (list + p).take(PlayersRepo.MAX))
    }

    override fun progress(id: String): ProgressRepo = ProgressStore(dir, fileOf(id))

    override fun remove(id: String) {
        val list = all()
        if (list.size <= 1 || list.none { it.id == id }) return
        save(list.filter { it.id != id })
        for (suffix in listOf("", ".bak", ".tmp")) File(dir, fileOf(id) + suffix).delete()
        if (activeId() == id) setActive(list.first { it.id != id }.id)
    }

    private fun fileOf(id: String) = if (id == "p1") ProgressStore.NAME else "progress-$id.json"

    private fun save(list: List<Player>) {
        prefs.edit().putString(K_PLAYERS, JSON.encodeToString(ListSerializer(Player.serializer()), list)).apply()
    }

    companion object {
        private const val K_PLAYERS = "players"
        private const val K_ACTIVE = "activePlayer"
        private const val AVATAR_FIRST = "lion"
        private val JSON = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    }
}
