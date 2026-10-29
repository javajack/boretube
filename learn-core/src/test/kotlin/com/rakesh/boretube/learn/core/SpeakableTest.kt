package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Test

class SpeakableTest {
    @Test fun symbolsBecomeWords() {
        assertEquals("7 times 8 is 56", Speakable.of("7 × 8 = 56", hindi = false))
        assertEquals("56 divided by 7 is 8", Speakable.of("56 ÷ 7 = 8", hindi = false))
        assertEquals("9 minus 4 plus 1", Speakable.of("9 − 4 + 1", hindi = false))
        assertEquals("7 गुणा 8 बराबर 56", Speakable.of("7 × 8 = 56", hindi = true))
    }
}
