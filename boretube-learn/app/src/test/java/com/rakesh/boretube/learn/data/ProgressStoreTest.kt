package com.rakesh.boretube.learn.data

import com.rakesh.boretube.learn.core.LearnState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class ProgressStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test fun roundTrips() {
        val s = LearnState(grade = 3, rung = 9, stars = mapOf("tablesLow" to 2), mastered = listOf("money"))
        ProgressStore(tmp.root).save(s)
        assertEquals(s, ProgressStore(tmp.root).load())
    }

    @Test fun aCorruptFileFallsBackToTheBackup() {
        val st = ProgressStore(tmp.root)
        st.save(LearnState(grade = 2))
        st.save(LearnState(grade = 3))
        File(tmp.root, "progress.json").writeText("{garbage")
        assertEquals(2, ProgressStore(tmp.root).load().grade)
    }

    @Test fun nothingSavedIsEmptyProgress() {
        assertEquals(LearnState(), ProgressStore(tmp.root).load())
        File(tmp.root, "progress.json").writeText("")
        assertEquals(LearnState(), ProgressStore(tmp.root).load())
    }

    @Test fun aHalfWrittenTempFileIsIgnored() {
        val st = ProgressStore(tmp.root)
        st.save(LearnState(grade = 5))
        File(tmp.root, "progress.json.tmp").writeText("{\"grade\":")
        assertEquals(5, ProgressStore(tmp.root).load().grade)
        assertTrue(File(tmp.root, "progress.json").exists())
    }
}
