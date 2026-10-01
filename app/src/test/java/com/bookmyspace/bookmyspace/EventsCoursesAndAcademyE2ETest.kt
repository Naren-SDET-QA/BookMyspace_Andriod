package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.Course
import com.bookmyspace.bookmyspace.data.model.Event
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class EventsCoursesAndAcademyE2ETest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testEventsBrowsingAndRegistrationFlow() {
        val events = BookMySpaceRepository.events.value
        assertTrue("Events list must not be empty", events.isNotEmpty())

        val firstEvent = events.first()
        val originalStatus = firstEvent.isRegistered

        // Toggle registration
        BookMySpaceRepository.toggleEventRegistration(firstEvent.id)
        val updatedEvent = BookMySpaceRepository.events.value.firstOrNull { it.id == firstEvent.id }
        assertNotNull("Updated event must exist", updatedEvent)
        assertEquals(!originalStatus, updatedEvent?.isRegistered)

        // Toggle back
        BookMySpaceRepository.toggleEventRegistration(firstEvent.id)
        val revertedEvent = BookMySpaceRepository.events.value.firstOrNull { it.id == firstEvent.id }
        assertEquals(originalStatus, revertedEvent?.isRegistered)
    }

    @Test
    fun testCourseBrowsingAndEnrollmentFlow() {
        val courses = BookMySpaceRepository.courses.value
        assertTrue("Courses list must not be empty", courses.isNotEmpty())

        val firstCourse = courses.first()
        val originalEnrolled = firstCourse.isEnrolled

        // Toggle enrollment
        BookMySpaceRepository.toggleCourseEnrollment(firstCourse.id)
        val updatedCourse = BookMySpaceRepository.courses.value.firstOrNull { it.id == firstCourse.id }
        assertNotNull("Updated course must exist", updatedCourse)
        assertEquals(!originalEnrolled, updatedCourse?.isEnrolled)

        // Verify key properties
        assertEquals("Pullela Champions Academy", firstCourse.academyName)
        assertTrue(firstCourse.durationWeeks > 0)
        assertTrue(firstCourse.price > 0.0)
    }
}
