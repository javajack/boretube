package com.rakesh.boretube.agent.core

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/** Shared JSON settings: tolerant of unknown fields, writes defaults. */
val AgentJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = false
    isLenient = false
}

/** A profile list entry: either `"pkg"` or `{"pkg": "...", "comment": "..."}`. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable(with = ProfilePackageSerializer::class)
data class ProfilePackage(val pkg: String, val comment: String = "")

@OptIn(ExperimentalSerializationApi::class)
object ProfilePackageSerializer : KSerializer<ProfilePackage> {
    override val descriptor: SerialDescriptor = JsonElement.serializer().descriptor
    override fun deserialize(decoder: Decoder): ProfilePackage {
        val el = (decoder as JsonDecoder).decodeJsonElement()
        return when (el) {
            is JsonPrimitive -> ProfilePackage(el.content)
            is JsonObject -> ProfilePackage(
                el["pkg"]?.jsonPrimitive?.content ?: throw IllegalArgumentException("pkg missing"),
                el["comment"]?.jsonPrimitive?.contentOrNull ?: "",
            )
            else -> throw IllegalArgumentException("bad profile package entry")
        }
    }

    override fun serialize(encoder: Encoder, value: ProfilePackage) {
        encoder.encodeSerializableValue(
            JsonObject.serializer(),
            JsonObject(mapOf("pkg" to JsonPrimitive(value.pkg), "comment" to JsonPrimitive(value.comment))),
        )
    }
}

@Serializable
data class StockYouTubeSpec(val pkg: String, val companions: List<String> = emptyList())

@Serializable
data class LauncherSpec(val pkg: String, val homeActivity: String = "", val a11yService: String = "")

/**
 * Device profile pushed by the phone to `POST /v1/profile`. Same format as
 * the files in `boretube-mobile/assets/profiles/`, plus two optional agent fields:
 * - `keepDisabled`: the cleanup/extras packages the phone applied and wants
 *   the watchdog to keep disabled. When absent, the watchdog captures the
 *   cleanup/extras packages that are disabled on its first run after the push.
 * - `inputPackages`: foreground packages that mean "an input (HDMI/tuner) is
 *   showing"; app rules do not apply to them and they don't count as TV time.
 */
@Serializable
data class DeviceProfile(
    val id: String = "unknown",
    val name: String = "",
    val readOnly: Boolean = false,
    val cleanup: List<ProfilePackage> = emptyList(),
    val extras: List<ProfilePackage> = emptyList(),
    val neverTouch: List<String> = emptyList(),
    val knownGood: Map<String, String> = emptyMap(),
    val stockYouTube: StockYouTubeSpec? = null,
    val launcher: LauncherSpec? = null,
    val quirks: List<String> = emptyList(),
    val keepDisabled: List<String>? = null,
    val inputPackages: List<String>? = null,
) {
    companion object {
        fun parse(text: String): DeviceProfile {
            val p = AgentJson.decodeFromString(serializer(), text)
            p.validate()
            return p
        }
    }

    fun toJson(): String = AgentJson.encodeToString(serializer(), this)

    fun validate() {
        val pkgs = cleanup.map { it.pkg } + extras.map { it.pkg } + neverTouch +
            knownGood.keys + listOfNotNull(stockYouTube?.pkg, launcher?.pkg) +
            (stockYouTube?.companions ?: emptyList()) + (keepDisabled ?: emptyList()) +
            (inputPackages ?: emptyList())
        for (p in pkgs) require(TvShell.isValidPackage(p)) { "invalid package \"$p\" in profile" }
        launcher?.a11yService?.takeIf { it.isNotEmpty() }?.let {
            require(TvShell.isValidComponent(it)) { "invalid a11yService \"$it\"" }
        }
    }
}

/** Protected package sets (ported from tv_ops.dart). */
object Protected {
    /** Packages no op may write to, whatever the profile says. */
    val BASELINE_NEVER_TOUCH = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.android.tv.settings",
        "com.android.vending",
        "com.google.android.gms",
        TvShell.AGENT_PACKAGE,
    )

    /**
     * Packages that must not be force-stopped: system, Home, input/key plumbing
     * and the agent. Ordinary apps on the never-touch list (e.g. SmartTube) may be
     * stopped; they just can't be disabled or removed.
     */
    val NEVER_STOP = setOf(
        "android",
        "com.android.systemui",
        "com.google.android.gms",
        "com.google.android.katniss",
        TvShell.LAUNCHERX,
        "com.google.android.tungsten.setupwraith",
        "com.realtek.advancesetting",
        "com.realtek.dtv",
        "com.realtek.tv.passthrough",
        "com.sony.dtv.smartui",
        TvShell.AGENT_PACKAGE,
    )

    /** Default "an input is on screen" packages for the VU3 (HDMI passthrough, tuner). */
    val DEFAULT_INPUT_PACKAGES = setOf(
        "com.realtek.tv.passthrough",
        "com.realtek.dtv",
        "com.realtek.tv.atv",
        "com.android.tv",
        "com.sony.dtv.tvx",
    )

    /** Always the home screen. */
    const val TVHOME = "com.gathin.tvhome"
}

/** Package protection derived from a profile (or none). */
class PackageGuard(private val profile: DeviceProfile?) {
    val neverTouch: Set<String> = Protected.BASELINE_NEVER_TOUCH + (profile?.neverTouch ?: emptyList())
    val homePackages: Set<String> = setOfNotNull(Protected.TVHOME, TvShell.LAUNCHERX, profile?.launcher?.pkg)
    val inputPackages: Set<String> = profile?.inputPackages?.toSet() ?: Protected.DEFAULT_INPUT_PACKAGES

    fun isProtected(pkg: String) = pkg in neverTouch

    /** Never `am force-stop` these: system plumbing, both launchers, the agent. */
    fun isStopProtected(pkg: String) =
        pkg in Protected.NEVER_STOP || pkg in homePackages || !TvShell.isValidPackage(pkg)

    fun isHome(pkg: String) = pkg in homePackages
    fun isInput(pkg: String) = pkg in inputPackages
}
