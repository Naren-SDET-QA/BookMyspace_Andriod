package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.auth.FirebaseAuthHelper
import com.bookmyspace.bookmyspace.data.auth.FirebaseAuthResult
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.viewmodel.AuthViewModel
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthWeakPasswordException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLooper

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class FirebaseAuthHelperAndViewModelTest {

    @Before
    fun setUp() {
        FirebaseAuthHelper.signOut()
        BookMySpaceRepository.logout()
        ShadowLooper.idleMainLooper()
    }

    @Test
    fun testFirebaseAuthHelper_ErrorParsing() {
        val invalidCredException = FirebaseAuthInvalidCredentialsException("ERROR_INVALID_EMAIL", "Invalid credentials")
        val parsedInvalid = FirebaseAuthHelper.parseAuthExceptionMessage(invalidCredException)
        assertTrue(parsedInvalid.contains("Invalid email or password", ignoreCase = true))

        val invalidUserException = FirebaseAuthInvalidUserException("ERROR_USER_NOT_FOUND", "No user")
        val parsedUser = FirebaseAuthHelper.parseAuthExceptionMessage(invalidUserException)
        assertTrue(parsedUser.contains("No account found", ignoreCase = true))

        val collisionException = FirebaseAuthUserCollisionException("ERROR_EMAIL_ALREADY_IN_USE", "User exists")
        val parsedCollision = FirebaseAuthHelper.parseAuthExceptionMessage(collisionException)
        assertTrue(parsedCollision.contains("already exists", ignoreCase = true))

        val genericEx = Exception("INVALID_LOGIN_CREDENTIALS: Bad password")
        val parsedGeneric = FirebaseAuthHelper.parseAuthExceptionMessage(genericEx)
        assertTrue(parsedGeneric.contains("Invalid email or password", ignoreCase = true))
    }

    @Test
    fun testFirebaseAuthHelper_SignInAndSignOut() = runBlocking {
        val result = FirebaseAuthHelper.signInWithEmailAndPassword("testuser@bookmyspace.com", "Password@123")
        assertTrue(result is FirebaseAuthResult.Success)

        val user = (result as FirebaseAuthResult.Success).data
        assertEquals("testuser@bookmyspace.com", user.email)
        assertEquals(user, FirebaseAuthHelper.currentAuthUser.value)
        assertEquals(user, BookMySpaceRepository.authUser.value)

        FirebaseAuthHelper.signOut()
        assertNull(FirebaseAuthHelper.currentAuthUser.value)
        assertNull(BookMySpaceRepository.authUser.value)
    }

    @Test
    fun testFirebaseAuthHelper_SignUpFlow() = runBlocking {
        val result = FirebaseAuthHelper.signUpWithEmailAndPassword(
            email = "newowner@bookmyspace.com",
            password = "Password@123",
            fullName = "Ananya Sharma",
            phone = "+91 9123456780",
            role = UserRole.VENUE_OWNER
        )

        assertTrue(result is FirebaseAuthResult.Success)
        val user = (result as FirebaseAuthResult.Success).data
        assertEquals("newowner@bookmyspace.com", user.email)
        assertEquals("Ananya Sharma", user.fullName)
        assertEquals(UserRole.VENUE_OWNER, user.role)
    }

    @Test
    fun testAuthViewModel_FormStateAndValidation() = runBlocking {
        val viewModel = AuthViewModel(FirebaseAuthHelper)
        ShadowLooper.idleMainLooper()

        // Change inputs
        viewModel.onFullNameChange("Narendra Reddy")
        viewModel.onEmailChange("invalid-email")
        viewModel.onPasswordChange("pass")
        viewModel.onConfirmPasswordChange("pass_different")
        viewModel.onRoleSelect(UserRole.VENUE_OWNER)
        viewModel.onAcceptTermsToggle(false)

        assertEquals("Narendra Reddy", viewModel.uiState.value.fullName)
        assertEquals("invalid-email", viewModel.uiState.value.email)
        assertEquals(UserRole.VENUE_OWNER, viewModel.uiState.value.selectedRole)

        // Trigger sign in with invalid email
        viewModel.signIn()
        ShadowLooper.idleMainLooper()
        assertNotNull(viewModel.uiState.value.errorMessage)
        assertTrue(viewModel.uiState.value.errorMessage!!.contains("valid email", ignoreCase = true))

        // Fix email but trigger signup with mismatched passwords
        viewModel.onEmailChange("valid@bookmyspace.com")
        viewModel.signUp()
        ShadowLooper.idleMainLooper()
        assertTrue(viewModel.uiState.value.errorMessage!!.contains("Password must be at least 6 characters", ignoreCase = true) ||
                viewModel.uiState.value.errorMessage!!.contains("Passwords do not match", ignoreCase = true))
    }

    @Test
    fun testAuthViewModel_SuccessfulSignInFlow() = runBlocking {
        val viewModel = AuthViewModel(FirebaseAuthHelper)

        viewModel.onEmailChange("user@bookmyspace.com")
        viewModel.onPasswordChange("Secret@123")
        val result = viewModel.executeSignIn()

        assertTrue(result is FirebaseAuthResult.Success)
        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNotNull(state.currentUser)
        assertEquals("user@bookmyspace.com", state.currentUser?.email)
        assertTrue(state.isAuthenticated)

        // Sign out
        viewModel.signOut()
        assertFalse(viewModel.uiState.value.isAuthenticated)
        assertNull(viewModel.uiState.value.currentUser)
    }

    @Test
    fun testAuthViewModel_SuccessfulSignUpFlow() = runBlocking {
        val viewModel = AuthViewModel(FirebaseAuthHelper)

        viewModel.setSignUpMode(true)
        viewModel.onFullNameChange("Rahul Dravid")
        viewModel.onEmailChange("rahul@cricketacademy.in")
        viewModel.onPasswordChange("StrongPassword@123")
        viewModel.onConfirmPasswordChange("StrongPassword@123")
        viewModel.onAcceptTermsToggle(true)
        viewModel.onRoleSelect(UserRole.VENUE_OWNER)

        val result = viewModel.executeSignUp()

        assertTrue(result is FirebaseAuthResult.Success)
        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertNotNull(state.currentUser)
        assertEquals("rahul@cricketacademy.in", state.currentUser?.email)
        assertEquals("Rahul Dravid", state.currentUser?.fullName)
        assertEquals(UserRole.VENUE_OWNER, state.currentUser?.role)
    }

    @Test
    fun testAuthViewModel_PasswordReset() = runBlocking {
        val viewModel = AuthViewModel(FirebaseAuthHelper)

        viewModel.onEmailChange("member@bookmyspace.com")
        val result = viewModel.executePasswordReset()

        assertTrue(result is FirebaseAuthResult.Success)
        val state = viewModel.uiState.value
        assertTrue(state.isPasswordResetSent)
        assertNotNull(state.successMessage)
    }
}

