package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.SkillSource
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlin.random.Random

/** What the town, paths and level cards need to know about a generated skill, without building it. */
@Serializable
data class SkillMeta(
    val id: String,
    val subject: String,
    val grade: Int,
    val title: String,
    val badge: String,
    val formats: List<String>,
    val tiers: Int,
    /** The generator that makes it: maths | english | evs | science. */
    val gen: String,
)

/**
 * A generated skill that builds its questions on first use (spec P2b). On
 * the VU3, building every generator up front took 7.7 s at launch; the
 * index (assets/content/data/index.json) makes start-up instant and the
 * generators run once, in the background or on the first question.
 */
class LazySkill(private val meta: SkillMeta, private val real: () -> SkillSource) : SkillSource {
    override val id = meta.id
    override val grade = meta.grade
    override val title = meta.title
    override val badge = meta.badge
    override val subject = meta.subject
    override val formats = meta.formats.mapNotNull { f -> Format.entries.firstOrNull { it.name == f } }
    override val tiers = meta.tiers
    override fun next(r: Random): Question = real().next(r)
    override fun next(r: Random, tier: Int): Question = real().next(r, tier)
    override fun next(r: Random, tier: Int, format: Format?): Question = real().next(r, tier, format)
    override fun build(key: String, r: Random): Question? = real().build(key, r)
    override fun easier(q: Question, r: Random): Question? = real().easier(q, r)
}

object GenIndex {
    val GENS = listOf("maths", "english", "evs", "science")
    /** Quick ones first, so most of the town is ready within a second or two. */
    private val WARM_ORDER = listOf("maths", "science", "english", "evs")
    private val JSON = Json { ignoreUnknownKeys = true; prettyPrint = true }

    fun build(gen: String, data: (String) -> String?): List<GenSkill> = when (gen) {
        "maths" -> MathsGen.skills(data)
        "english" -> EnglishGen.skills(data)
        "evs" -> EvsGen.skills(data)
        "science" -> ScienceGen.skills(data)
        else -> emptyList()
    }

    /** The index for every generator (tests write and check `index.json` with this). */
    fun of(data: (String) -> String?): List<SkillMeta> = GENS.flatMap { gen ->
        build(gen, data).map { s -> SkillMeta(s.id, s.subject, s.grade, s.title, s.badge, s.formats.map { it.name }, s.tiers, gen) }
    }

    fun encode(index: List<SkillMeta>): String = JSON.encodeToString(ListSerializer(SkillMeta.serializer()), index) + "\n"

    fun decode(text: String): List<SkillMeta> = JSON.decodeFromString(ListSerializer(SkillMeta.serializer()), text)

    /**
     * Lazy skills from `index.json`; each generator runs once, when one of its
     * skills is first asked for a question (or [Loader.warm] runs it early).
     */
    class Loader(private val data: (String) -> String?) {
        // One lock per generator: a maths question never waits for EVS to finish building.
        private val built: Map<String, Lazy<Map<String, GenSkill>>> = GENS.associateWith { g -> lazy { build(g, data).associateBy { it.id } } }

        fun skillsOf(gen: String): Map<String, GenSkill> = built[gen]?.value.orEmpty()

        fun skills(): List<SkillSource> {
            val index = data("index.json")?.let { runCatching { decode(it) }.getOrNull() } ?: return emptyList()
            return index.map { m -> LazySkill(m) { skillsOf(m.gen)[m.id] ?: error("${m.id} is in index.json but its generator didn't make it") } }
        }

        /** Builds every generator now (call off the main thread). */
        fun warm() { for (g in WARM_ORDER) skillsOf(g) }
    }
}
