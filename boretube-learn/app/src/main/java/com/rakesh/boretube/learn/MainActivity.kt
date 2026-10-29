package com.rakesh.boretube.learn

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.rakesh.boretube.learn.data.ProgressStore
import com.rakesh.boretube.learn.data.SettingsStore
import com.rakesh.boretube.learn.sound.SoundPoolSounds
import com.rakesh.boretube.learn.speech.TtsSpeaker
import com.rakesh.boretube.learn.ui.DesignFrame
import com.rakesh.boretube.learn.ui.LearnApp
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
        setContent {
            DesignFrame {
                LearnApp(progress, settings, sounds, speaker, Random.Default, onExit = { finish() })
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
