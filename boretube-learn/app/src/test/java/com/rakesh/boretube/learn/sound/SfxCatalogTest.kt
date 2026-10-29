package com.rakesh.boretube.learn.sound

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class SfxCatalogTest {
    @Test fun everySoundHasAFile() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        for (s in Sfx.entries) {
            assertTrue("res/raw/${s.res}.ogg is missing", ctx.resources.getIdentifier(s.res, "raw", ctx.packageName) != 0)
        }
    }

    @Test fun rightAnswersClimbAndClampToFive() {
        assertEquals(Sfx.right_1, Sfx.right(0))
        assertEquals(Sfx.right_1, Sfx.right(1))
        assertEquals(Sfx.right_3, Sfx.right(3))
        assertEquals(Sfx.right_5, Sfx.right(9))
    }

    @Test fun focusTicksAreRateLimited() {
        val gate = TickGate(120)
        assertTrue(gate.allow(1_000))
        assertTrue(!gate.allow(1_100))
        assertTrue(gate.allow(1_121))
    }

    @Test fun mutedSoundsPlayNothing() {
        val played = mutableListOf<Sfx>()
        val s = RecordingSounds(enabled = { false }) { played += it }
        s.play(Sfx.select)
        s.right(2)
        assertTrue(played.isEmpty())
    }
}
