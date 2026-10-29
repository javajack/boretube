package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Test

class LearningRulesTest {
    @Test fun rulesValidateLearning() {
        Rules(learning = LearningRules(enabled = true, grade = 3)).validate()
        for (bad in listOf(LearningRules(grade = 8), LearningRules(lang = "fr"), LearningRules(perBreak = 0),
            LearningRules(trigger = "always"), LearningRules(everyMin = 1))) {
            try { Rules(learning = bad).validate(); fail("accepted $bad") } catch (_: IllegalArgumentException) {}
        }
        val back = Rules.parse(Rules(learning = LearningRules(true, 2, "enHi", false, 4, "every", 20)).toJson())
        assertEquals(LearningRules(true, 2, "enHi", false, 4, "every", 20), back.learning)
        assertNull(Rules.parse("{}").learning)
    }

    @Test fun actionsValidate() {
        assertNull(ActionRequest("brainBreak").validate())
        assertNull(ActionRequest("endBrainBreak").validate())
    }
}
