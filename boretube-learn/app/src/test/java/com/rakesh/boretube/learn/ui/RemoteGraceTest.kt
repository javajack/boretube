package com.rakesh.boretube.learn.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteGraceTest {
    private val g = OkGrace(350)

    @Test fun okRightAfterAScreenChangeIsIgnored() {
        assertFalse(g.accept(RemoteKey.Ok, 0, now = 1_200, since = 1_000))
        assertTrue(g.accept(RemoteKey.Ok, 0, now = 1_350, since = 1_000))
    }

    @Test fun aHeldOkIsIgnoredButArrowsRepeat() {
        assertFalse(g.accept(RemoteKey.Ok, 3, now = 9_000, since = 1_000))
        assertTrue(g.accept(RemoteKey.Right, 3, now = 1_001, since = 1_000))
    }
}
