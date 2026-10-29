package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.github.takahirom.roborazzi.captureRoboImage
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/**
 * Every picture the content may name is drawn, and each group gets a
 * contact sheet (`-Pgroup=animals` for one group) to look at.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class PicturesTest {
    @get:Rule val rule = createComposeRule()

    private val groups: Map<String, List<String>> by lazy {
        val j = Json.parseToJsonElement(File("src/main/assets/content/data/pictures.json").readText()) as JsonObject
        j.filterKeys { !it.startsWith("_") }.mapValues { (_, v) -> (v as JsonArray).map { (it as JsonPrimitive).content } }
    }

    @Test fun everyListedPictureIsDrawn() {
        val missing = groups.values.flatten().filter { it !in Pictures.ids }
        assertTrue("${missing.size} not drawn yet: ${missing.joinToString()}", missing.isEmpty())
    }

    @Test fun contactSheets() {
        val only = System.getProperty("pictures.group")?.takeIf { it.isNotBlank() }
        val sheets = groups.filterKeys { only == null || it == only }.flatMap { (g, ids) ->
            ids.filter { it in Pictures.ids }.chunked(32).mapIndexed { i, page -> "$g-${i + 1}" to page }
        }
        val current = androidx.compose.runtime.mutableStateOf<Pair<String, List<String>>?>(sheets.firstOrNull())
        rule.setContent {
            DesignFrame {
                val sheet = current.value ?: return@DesignFrame
                Column(Modifier.fillMaxSize().background(Palette.canvas).padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    BasicText(sheet.first, style = Text.display(TypeScale.s21))
                    for (row in sheet.second.chunked(8)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            for (id in row) {
                                Column(Modifier.width(140.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Column(Modifier.size(110.dp).background(Palette.card).padding(8.dp)) { PictureArt(id, Modifier.size(94.dp)) }
                                    BasicText(id, style = Text.body(TypeScale.s18))
                                }
                            }
                        }
                    }
                }
            }
        }
        for (s in sheets) {
            current.value = s
            rule.waitForIdle()
            rule.onRoot().captureRoboImage("build/pictures/${s.first}.png")
        }
    }
}
