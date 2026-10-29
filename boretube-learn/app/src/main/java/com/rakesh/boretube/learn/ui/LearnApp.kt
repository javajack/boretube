package com.rakesh.boretube.learn.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.rakesh.boretube.learn.core.Cheer
import com.rakesh.boretube.learn.core.Chest
import com.rakesh.boretube.learn.core.Learner
import com.rakesh.boretube.learn.core.Ranks
import com.rakesh.boretube.learn.core.LevelResult
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.data.Player
import com.rakesh.boretube.learn.data.PlayersRepo
import com.rakesh.boretube.learn.data.ProgressRepo
import com.rakesh.boretube.learn.world.Discover
import com.rakesh.boretube.learn.data.SettingsRepo
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.level.LevelScreen
import com.rakesh.boretube.learn.ui.level.RunDoneScreen
import com.rakesh.boretube.learn.ui.level.RunScreen
import com.rakesh.boretube.learn.core.Runs
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
    data class Done(val result: LevelResult, val skillId: String, val rankUp: String? = null, val chestOpened: Boolean = false) : Screen
    data object Stickers : Screen
    data class Run(val land: LandId, val nonce: Int) : Screen
    data object Who : Screen
    data object Avatar : Screen
    data class NewPlayer(val pic: String) : Screen
    data object Class : Screen
    data object Settings : Screen
    data class RunDone(val run: com.rakesh.boretube.learn.core.Run, val record: Boolean, val land: LandId) : Screen
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
    /** The children sharing this TV (null: one child, [progress] and [settingsRepo] only). */
    players: PlayersRepo? = null,
    onExit: () -> Unit,
) {
    var player by remember { mutableStateOf(players?.active()) }
    var progress by remember { mutableStateOf(player?.let { players!!.progress(it.id) } ?: progress) }
    fun settingsOf(p: Player?) = settingsRepo.get().let { b -> if (p == null) b else b.copy(grade = p.grade, lang = p.lang, set = true) }
    var settings by remember { mutableStateOf(settingsOf(player)) }
    var state by remember { mutableStateOf(Learner.forGrade(progress.load(), settings.grade)) }
    var screen by remember {
        mutableStateOf<Screen>(
            when {
                players != null && player == null -> Screen.Avatar
                settings.set -> Screen.Town
                else -> Screen.FirstRun
            },
        )
    }
    var nonce by remember { mutableIntStateOf(0) }

    /** Plays as [p] from now on: their progress, class and language. */
    fun become(p: Player) {
        progress.save(state)
        players?.setActive(p.id)
        player = p
        progress = players!!.progress(p.id)
        settings = settingsOf(p)
        state = Learner.forGrade(progress.load(), p.grade)
        progress.save(state)
    }

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
            Screen.Town -> TownScreen(
                state, settings, sounds, hour(), world,
                player = player,
                discoveries = remember(state, settings.grade) { Discover.today(state, world, settings.grade, today()) },
                onPlayers = { screen = Screen.Who }.takeIf { players != null },
                onClass = { screen = Screen.Class },
                onSettings = { screen = Screen.Settings },
                onStickers = { screen = Screen.Stickers },
                festive = com.rakesh.boretube.learn.core.Seasons.of(today()),
                hello = Cheer.greeting(hour(), today(), state.mastered.lastOrNull()?.takeIf { world.catalog.skill(it) != null }?.let { world.title(it) }),
                onDiscover = { d ->
                    if (d.skill == null) { nonce++; sounds.play(Sfx.run_start); screen = Screen.Run(d.land, nonce) } else play(d.skill)
                },
                onBack = onExit,
            ) { id ->
                sounds.play(Sfx.enter_bazaar)
                screen = Screen.Land(id)
            }
            Screen.Who -> WhoScreen(
                players!!.all(), player?.id,
                stars = { id -> if (id == player?.id) state.stars.values.sum() else players.progress(id).load().stars.values.sum() },
                sounds = sounds,
                onPick = { id -> players.all().firstOrNull { it.id == id }?.let { if (it.id != player?.id) become(it) }; screen = Screen.Town },
                onNew = { screen = Screen.Avatar },
                onBack = { screen = Screen.Town },
            )
            Screen.Avatar -> AvatarScreen(
                taken = players?.all()?.map { it.pic }?.toSet().orEmpty(),
                sounds = sounds,
                onPick = { pic -> screen = Screen.NewPlayer(pic) },
                onBack = { screen = if (player == null) Screen.Avatar.also { onExit() } else Screen.Who },
            )
            is Screen.NewPlayer -> FirstRunScreen(sounds, onDone = { picked ->
                val p = Player(players!!.newId(), s.pic, picked.grade, picked.lang)
                players.put(p)
                settingsRepo.put(settingsRepo.get().copy(set = true))
                become(p)
                screen = Screen.Town
            }, onBack = { screen = Screen.Avatar })
            Screen.Settings -> SettingsScreen(
                settings, player, canRemove = (players?.all()?.size ?: 0) > 1, sounds = sounds,
                onChange = { n ->
                    settings = n
                    settingsRepo.put(settingsRepo.get().copy(sounds = n.sounds, music = n.music, lang = n.lang))
                    val p = player
                    if (p != null && players != null) { val q = p.copy(lang = n.lang); players.put(q); player = q }
                },
                onRemove = {
                    val p = player
                    if (p != null && players != null) {
                        players.remove(p.id)
                        // Switch without saving: the removed player's file must stay gone.
                        players.active()?.let { next ->
                            player = next
                            progress = players.progress(next.id)
                            settings = settingsOf(next)
                            state = Learner.forGrade(progress.load(), next.grade)
                        }
                    }
                    screen = Screen.Town
                },
                onBack = { screen = Screen.Town },
            )
            Screen.Class -> ClassScreen(settings.grade, sounds, onPick = { g ->
                if (g != settings.grade) {
                    val p = player
                    if (p != null && players != null) { val q = p.copy(grade = g); players.put(q); player = q }
                    settings = settings.copy(grade = g)
                    settingsRepo.put(settingsRepo.get().copy(grade = g))
                    state = Learner.forGrade(state, g)
                    progress.save(state)
                }
                screen = Screen.Town
            }, onBack = { screen = Screen.Town })
            is Screen.Land -> LandScreen(
                world.of(s.id), state, settings, sounds, world,
                onRun = { nonce++; screen = Screen.Run(s.id, nonce) }.takeIf { world.path(world.of(s.id), settings.grade).isNotEmpty() },
                onPlay = ::play,
                onBack = { screen = Screen.Town },
            )
            is Screen.Run -> {
                val land = world.of(s.land)
                RunScreen(
                    land = s.land.name,
                    landName = land.name,
                    pool = world.path(land, settings.grade).mapNotNull { world.catalog.skill(it) },
                    settings = settings, sounds = sounds, speaker = speaker, random = random,
                    onDone = { run, answers ->
                        var st = state
                        val day = today()
                        for (a in answers) st = Learner.record(st, a.q, a.correct, a.ms, now(), day)
                        val record = Runs.isRecord(st, run)
                        state = Chest.played(Runs.finish(st, run), day, TREASURES)
                        progress.save(state)
                        screen = if (answers.isEmpty()) Screen.Land(s.land) else Screen.RunDone(run, record, s.land)
                    },
                    onLeave = { screen = Screen.Land(s.land) },
                )
            }
            is Screen.RunDone -> RunDoneScreen(
                s.run, s.record, world.of(s.land).name, sounds,
                onAgain = { nonce++; sounds.play(Sfx.run_start); screen = Screen.Run(s.land, nonce) },
                onBack = { screen = Screen.Land(s.land) },
            )
            is Screen.Level -> LevelScreen(
                s.skillId, state, settings, sounds, speaker, random, now(), world.catalog,
                onDone = { answers ->
                    val played = Levels.formatFor(s.skillId, state, world.catalog)
                    val tierBefore = Levels.tierOf(state, s.skillId)
                    val r = Levels.finish(state, s.skillId, answers, today(), now(), world.catalog, played)
                    val wasOpen = Chest.status(r.state, today()).open
                    val withChest = Chest.played(r.state, today(), TREASURES)
                    state = withChest
                    progress.save(state)
                    val rankUp = Ranks.rankUp(world.title(s.skillId), tierBefore, Levels.tierOf(withChest, s.skillId))
                    screen = Screen.Done(r.copy(state = withChest), s.skillId, rankUp, !wasOpen && Chest.status(withChest, today()).open)
                },
                onLeave = { screen = Screen.Land(world.landOf(s.skillId).id) },
            )
            Screen.Stickers -> StickerBookScreen(state, world, today(), sounds, onBack = { screen = Screen.Town })
            is Screen.Done -> DoneScreen(
                s.result, world.title(s.skillId), sounds,
                sticker = stickerFor(s.skillId, world),
                rankUp = s.rankUp,
                chest = Chest.status(s.result.state, today()),
                chestOpenedNow = s.chestOpened,
                onAnother = {
                    // The level the path offers next: the child's rung, or this skill again.
                    play(world.progress(state, world.landOf(s.skillId), settings.grade).next ?: s.skillId)
                },
                onTown = { screen = Screen.Town },
            )
        }
    }
}
