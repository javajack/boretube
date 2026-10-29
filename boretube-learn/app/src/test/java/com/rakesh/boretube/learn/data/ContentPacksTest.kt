package com.rakesh.boretube.learn.data

import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.Pack
import com.rakesh.boretube.learn.core.PackValidator
import com.rakesh.boretube.learn.ui.Pictures
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.random.Random

/** Every shipped bank passes the spec §4 checks (tools/content/packs.py writes them). */
class ContentPacksTest {
    private val dir = File("src/main/assets/content")
    private val json = Json { ignoreUnknownKeys = true }
    // content/data holds the generators' tables, not packs.
    private val packs = dir.walk().filter { it.extension == "json" && it.parentFile.name != "data" }.map { json.decodeFromString(Pack.serializer(), it.readText()) }.toList()

    @Test fun everyPackIsValid() {
        assertEquals(16, packs.size)
        val errors = packs.flatMap { PackValidator.check(it, Pictures.ids) }
        assertTrue(errors.joinToString("\n"), errors.isEmpty())
    }

    @Test fun everyClassHasEnglishAndEvs() {
        for (subject in listOf("english", "evs")) {
            assertEquals(subject, (0..7).toSet(), packs.filter { it.subject == subject }.map { it.grade }.toSet())
        }
    }

    @Test fun skillIdsAreUniqueAcrossPacksAndEveryQuestionBuilds() {
        val ids = packs.flatMap { p -> p.skills.map { it.id } }
        assertEquals(ids.size, ids.toSet().size)
        val c = Catalog.of(packs)
        for (id in ids) repeat(20) { seed ->
            val q = c.skill(id)!!.next(Random(seed))
            assertEquals(q.answerText, c.fromKey(q.key, Random(seed + 1))!!.answerText)
        }
    }
}
