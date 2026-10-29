package com.rakesh.boretube.learn.data

import android.content.res.AssetManager
import android.util.Log
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Pack
import com.rakesh.boretube.learn.core.gen.Generated
import com.rakesh.boretube.learn.core.PackValidator
import com.rakesh.boretube.learn.ui.Pictures
import kotlinx.serialization.json.Json

/**
 * The written banks shipped in assets/content/<subject>/<class>.json. Only
 * packs a grown-up has reviewed reach a child (spec §4), unless
 * [includeUnreviewed] (debug builds). A pack that fails the checks is skipped.
 */
object ContentRepo {
    private val JSON = Json { ignoreUnknownKeys = true }

    fun load(assets: AssetManager, includeUnreviewed: Boolean): List<Pack> {
        val out = mutableListOf<Pack>()
        for (subject in PackValidator.SUBJECTS) {
            val files = runCatching { assets.list("content/$subject")?.toList() }.getOrNull().orEmpty()
            for (f in files.filter { it.endsWith(".json") }) {
                val pack = runCatching {
                    JSON.decodeFromString(Pack.serializer(), assets.open("content/$subject/$f").bufferedReader().readText())
                }.getOrElse { Log.w(TAG, "bad pack $subject/$f", it); null } ?: continue
                val errors = PackValidator.check(pack, Pictures.ids)
                if (errors.isNotEmpty()) { Log.w(TAG, "skipping ${pack.id}: ${errors.first()}"); continue }
                if (pack.reviewed.done || includeUnreviewed) out += pack
            }
        }
        return out
    }

    /**
     * The generated skills (spec P2b), built from the tables in
     * assets/content/data. Their questions are all checked by the learn-core
     * tests, so they need no review gate; a skill that fails to build is
     * left out.
     */
    fun generated(assets: AssetManager): List<GenSkill> {
        val data: (String) -> String? = { name -> runCatching { assets.open("content/data/$name").bufferedReader().readText() }.getOrNull() }
        val t0 = System.nanoTime()
        val out = runCatching { Generated.skills(data) }.getOrElse { Log.w(TAG, "generated skills failed", it); emptyList() }
        Log.i(TAG, "generated ${out.size} skills in ${(System.nanoTime() - t0) / 1_000_000} ms")
        return out
    }

    private const val TAG = "BoretubeLearnContent"
}
