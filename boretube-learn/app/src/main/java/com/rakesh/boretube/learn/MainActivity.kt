package com.rakesh.boretube.learn

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.rakesh.boretube.learn.data.ContentRepo
import com.rakesh.boretube.learn.data.PlayersStore
import com.rakesh.boretube.learn.data.ProgressStore
import com.rakesh.boretube.learn.data.SettingsStore
import com.rakesh.boretube.learn.sound.SoundPoolSounds
import com.rakesh.boretube.learn.speech.TtsSpeaker
import com.rakesh.boretube.learn.ui.DesignFrame
import com.rakesh.boretube.learn.ui.LearnApp
import com.rakesh.boretube.learn.world.World
import kotlin.random.Random

class MainActivity : ComponentActivity() {
    private lateinit var sounds: SoundPoolSounds
    private lateinit var speaker: TtsSpeaker

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val settings = SettingsStore(getSharedPreferences("learn", Context.MODE_PRIVATE))
        sounds = SoundPoolSounds(this) { settings.get().sounds }
        speaker = TtsSpeaker(this)
        val progress = ProgressStore(filesDir)
        val players = PlayersStore(getSharedPreferences("learn", Context.MODE_PRIVATE), filesDir)
        val generated = ContentRepo.generated(assets)
        val world = World.of(ContentRepo.load(assets, includeUnreviewed = BuildConfig.DEBUG), generated.skills())
        // The generators take seconds on a TV chip: build them while the child looks at the town.
        Thread({ ContentRepo.warm(generated) }, "generators").apply { priority = Thread.MIN_PRIORITY }.start()
        // Festival preview for grown-ups and screenshots:
        //   adb shell am start -n com.rakesh.boretube.learn/.MainActivity --es preview_day 2026-11-08
        // Only the town's decorations and greeting follow it; progress keeps the real date.
        val preview = intent?.getStringExtra("preview_day")?.let { runCatching { java.time.LocalDate.parse(it) }.getOrNull() }
        setContent {
            DesignFrame {
                LearnApp(
                    progress, settings, sounds, speaker, Random.Default, world = world, players = players,
                    festiveDay = { preview ?: java.time.LocalDate.now() },
                    onExit = { finish() },
                )
            }
        }
    }

    override fun onStop() {
        super.onStop()
        speaker.stop()
    }

    override fun onDestroy() {
        super.onDestroy()
        sounds.release()
        speaker.shutdown()
    }
}
