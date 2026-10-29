package com.rakesh.boretube.learn.data

import android.content.res.AssetManager
import android.util.Log
import com.rakesh.boretube.learn.core.Pack
import com.rakesh.boretube.learn.core.gen.GenIndex
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
     * The generated skills (spec P2b), from assets/content/data. Start-up reads
     * only the small index; each generator runs on first use, and
     * [GenIndex.Loader.warm] (off the main thread) runs them all early. Their
     * questions are all checked by the learn-core tests, so they need no
     * review gate.
     */
    fun generated(assets: AssetManager): GenIndex.Loader =
        GenIndex.Loader { name -> runCatching { assets.open("content/data/$name").bufferedReader().readText() }.getOrNull() }

    /** Builds every generator now, logging how long it took. Never throws. */
    fun warm(loader: GenIndex.Loader) {
        val t0 = System.nanoTime()
        runCatching { loader.warm() }.onFailure { Log.w(TAG, "generated skills failed", it) }
        Log.i(TAG, "generators warm in ${(System.nanoTime() - t0) / 1_000_000} ms")
    }

    private const val TAG = "BoretubeLearnContent"
}
