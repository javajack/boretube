package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.requestFocus
import androidx.compose.ui.unit.dp
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h720dp-xhdpi")
class FocusRingTest {
    @get:Rule val rule = createComposeRule()

    @Test fun onlyTheFocusedItemIsMarked() {
        rule.setContent {
            Row {
                repeat(3) { i ->
                    Box(Modifier.testTag("b$i").size(100.dp).focusRing(RoundedCornerShape(Radii.r21)).focusable())
                }
            }
        }
        rule.onNodeWithTag("b1").requestFocus()
        rule.waitForIdle()
        rule.onNodeWithTag("b1").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        rule.onNodeWithTag("b0").assert(SemanticsMatcher.expectValue(FocusedKey, false))
        rule.onNodeWithTag("b1").assert(SemanticsMatcher.expectValue(SemanticsProperties.Focused, true))
    }
}
