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
        setContent {
            DesignFrame {
                LearnApp(progress, settings, sounds, speaker, Random.Default, world = world, players = players, onExit = { finish() })
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
