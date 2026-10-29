package com.rakesh.boretube.learn.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.rakesh.boretube.learn.core.Learner
import com.rakesh.boretube.learn.core.LevelResult
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.data.ProgressRepo
import com.rakesh.boretube.learn.data.SettingsRepo
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.level.LevelScreen
import com.rakesh.boretube.learn.world.LandId
import com.rakesh.boretube.learn.world.World
import java.time.LocalDate
import java.time.LocalTime
import kotlin.random.Random

private sealed interface Screen {
    data object FirstRun : Screen
    data object Town : Screen
    data class Land(val id: LandId) : Screen
    data class Level(val skillId: String, val nonce: Int) : Screen
    data class Done(val result: LevelResult, val skillId: String) : Screen
}

/** The whole app: first run, the town, a land, a level, level done. Progress is saved after every level. */
@Composable
fun LearnApp(
    progress: ProgressRepo,
    settingsRepo: SettingsRepo,
    sounds: Sounds,
    speaker: Speaker,
    random: Random,
    now: () -> Long = { System.currentTimeMillis() },
    today: () -> LocalDate = { LocalDate.now() },
    hour: () -> Int = { LocalTime.now().hour },
    world: World = World.MATHS,
    onExit: () -> Unit,
) {
    var settings by remember { mutableStateOf(settingsRepo.get()) }
    var state by remember { mutableStateOf(Learner.forGrade(progress.load(), settings.grade)) }
    var screen by remember { mutableStateOf<Screen>(if (settings.set) Screen.Town else Screen.FirstRun) }
    var nonce by remember { mutableIntStateOf(0) }

    fun play(skillId: String) {
        nonce++
        screen = Screen.Level(skillId, nonce)
    }

    key(screen) {
        when (val s = screen) {
            Screen.FirstRun -> FirstRunScreen(sounds, onDone = { picked ->
                settings = picked
                settingsRepo.put(picked)
                state = Learner.forGrade(state, picked.grade)
                progress.save(state)
                screen = Screen.Town
            }, onBack = onExit)
            Screen.Town -> TownScreen(state, settings, sounds, hour(), world, onBack = onExit) { id ->
                sounds.play(Sfx.enter_bazaar)
                screen = Screen.Land(id)
            }
            is Screen.Land -> LandScreen(world.of(s.id), state, settings, sounds, world, onPlay = ::play, onBack = { screen = Screen.Town })
            is Screen.Level -> LevelScreen(
                s.skillId, state, settings, sounds, speaker, random, now(), world.catalog,
                onDone = { answers ->
                    val r = Levels.finish(state, s.skillId, answers, today(), now())
                    state = r.state
                    progress.save(state)
                    screen = Screen.Done(r, s.skillId)
                },
                onLeave = { screen = Screen.Land(world.landOf(s.skillId).id) },
            )
            is Screen.Done -> DoneScreen(
                s.result, world.title(s.skillId), sounds,
                onAnother = {
                    // The level the path offers next: the child's rung, or this skill again.
                    play(world.progress(state, world.landOf(s.skillId), settings.grade).next ?: s.skillId)
                },
                onTown = { screen = Screen.Town },
            )
        }
    }
}
