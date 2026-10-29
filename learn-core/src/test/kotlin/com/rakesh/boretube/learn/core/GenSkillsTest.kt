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
