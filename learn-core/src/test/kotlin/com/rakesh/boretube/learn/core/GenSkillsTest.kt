package com.rakesh.boretube.learn.core

import com.rakesh.boretube.learn.core.gen.Generated
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.random.Random

/**
 * Runs every check over every generated question (spec P2b §6) and prints
 * the volume. `-Dgen.subject=english` (maths | english | evs | science)
 * limits it to one subject while authoring.
 */
class GenSkillsTest {
    private val dir = File("../boretube-learn/app/src/main/assets/content/data")
    private val data: (String) -> String? = { n -> File(dir, n).takeIf { it.exists() }?.readText() }
    private val subject: String? = System.getProperty("gen.subject")?.takeIf { it.isNotBlank() }

    private fun skills(): List<GenSkill> =
        if (subject == null) Generated.skills(data) else Generated.subject(subject, data)

    @Test fun everyGeneratedQuestionPassesTheChecks() {
        val errors = mutableListOf<String>()
        val ids = HashSet<String>()
        for (s in skills()) {
            if (!ids.add(s.id)) errors += "${s.id}: skill id repeats"
            if (s.grade !in 0..Maths.MAX_GRADE) errors += "${s.id}: grade ${s.grade}"
            errors += GenChecks.skill(s).take(15)
        }
        assertTrue(errors.take(80).joinToString("\n"), errors.isEmpty())
    }

    /** Picture ids the app draws (assets/content/data/pictures.json). */
    private val pictures: Set<String> by lazy {
        val j = kotlinx.serialization.json.Json.parseToJsonElement(File(dir, "pictures.json").readText()) as kotlinx.serialization.json.JsonObject
        j.filterKeys { !it.startsWith("_") }.values.flatMap { v -> (v as kotlinx.serialization.json.JsonArray).map { (it as kotlinx.serialization.json.JsonPrimitive).content } }.toSet()
    }

    @Test fun everyPictureExists() {
        val bad = mutableListOf<String>()
        for (s in skills()) for (q in s.all()) {
            val ids = listOfNotNull((q.visual as? Visual.Picture)?.id, (q.learnVisual as? Visual.Picture)?.id) +
                (q.options + q.order.orEmpty()).filter { it.startsWith("pic:") }.map { it.removePrefix("pic:") }
            for (id in ids) if (id !in pictures) bad += "${q.key}: unknown picture $id"
            if (Format.catch in s.formats && q.options.any { it.startsWith("pic:") }) bad += "${q.key}: Catch can't show picture options"
            if (bad.size > 40) break
        }
        assertTrue(bad.joinToString("\n"), bad.isEmpty())
    }

    @Test fun keysRebuildTheSameQuestion() {
        val r = Random(11)
        for (s in skills()) {
            repeat(20) {
                val q = s.next(r, 1 + it % 3)
                val again = s.build(q.key, Random(99))
                assertTrue("${q.key} doesn't rebuild", again != null && again.prompt == q.prompt && again.answerText == q.answerText)
            }
        }
    }

    @Test fun volumeReport() {
        val bySubject = sortedMapOf<String, Int>()
        val lines = mutableListOf<String>()
        for (s in skills()) {
            val n = GenChecks.count(s)
            bySubject[s.subject] = (bySubject[s.subject] ?: 0) + n
            lines += "%-24s %-8s class %d  tiers %d  %-28s %7d".format(s.id, s.subject, s.grade, s.tiers, s.formats.joinToString(","), n)
        }
        val out = File("build/gen-volume.txt")
        out.parentFile.mkdirs()
        out.writeText((lines + "" + bySubject.map { "${it.key}: ${it.value}" } + "total: ${bySubject.values.sum()}").joinToString("\n"))
        println(out.readText())
        if (subject == null) {
            val words = (bySubject["english"] ?: 0) + (bySubject["evs"] ?: 0) + (bySubject["science"] ?: 0)
            assertTrue("English + EVS + Science: $words (needs 85000)", words >= 85_000)
        }
    }
}

/**
 * The shipped skill index matches the generators. After changing a
 * generator, refresh it: `./gradlew test -Pgen.subject=index --tests '*GenIndexTest*'`.
 */
class GenIndexTest {
    private val dir = File("../boretube-learn/app/src/main/assets/content/data")
    private val data: (String) -> String? = { n -> File(dir, n).takeIf { it.exists() }?.readText() }

    @Test fun theShippedIndexMatchesTheGenerators() {
        val fresh = com.rakesh.boretube.learn.core.gen.GenIndex.encode(com.rakesh.boretube.learn.core.gen.GenIndex.of(data))
        val file = File(dir, "index.json")
        if (System.getProperty("gen.subject") == "index") file.writeText(fresh)
        assertTrue("index.json is stale: run ./gradlew test -Pgen.subject=index --tests '*GenIndexTest*'", file.exists() && file.readText() == fresh)
    }

    @Test fun lazySkillsBuildOnFirstUseAndMatch() {
        val loader = com.rakesh.boretube.learn.core.gen.GenIndex.Loader(data)
        val lazy = loader.skills()
        assertTrue(lazy.size > 200)
        val r = Random(3)
        for (s in lazy.shuffled(r).take(25)) {
            val q = s.next(r, s.tiers)
            assertTrue(q.key.startsWith("${s.id}:"))
            assertTrue(s.build(q.key, Random(1))!!.prompt == q.prompt)
        }
    }
}
