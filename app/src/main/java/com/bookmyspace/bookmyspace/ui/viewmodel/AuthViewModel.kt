package com.bookmyspace.bookmyspace.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bookmyspace.bookmyspace.data.auth.FirebaseAuthHelper
import com.bookmyspace.bookmyspace.data.auth.FirebaseAuthResult
import com.bookmyspace.bookmyspace.data.model.AuthUser
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.google.firebase.auth.AuthCredential
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UI State representing the authentication screen state and form fields.
 */
data class AuthUiState(
    val isLoading: Boolean = false,
    val isSignUpMode: Boolean = false,
    val fullName: String = "",
    val email: String = "",
    val phone: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val selectedRole: UserRole = UserRole.USER,
    val acceptTerms: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null,
    val isVerificationEmailSent: Boolean = false,
    val isPasswordResetSent: Boolean = false,
    val currentUser: AuthUser? = null
) {
    val isAuthenticated: Boolean
        get() = currentUser != null
}

/**
 * Single-event side effects for navigation and toasts.
 */
sealed class AuthNavigationEvent {
    data class NavigateToHome(val userRole: UserRole) : AuthNavigationEvent()
    data class ShowToast(val message: String) : AuthNavigationEvent()
    data object NavigateToEmailVerification : AuthNavigationEvent()
}

/**
 * AuthViewModel: Manages user authentication state, input validations,
 * and delegates login and registration workflows to [FirebaseAuthHelper].
 */
class AuthViewModel(
    private val authHelper: FirebaseAuthHelper = FirebaseAuthHelper
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<AuthNavigationEvent>()
    val events: SharedFlow<AuthNavigationEvent> = _events.asSharedFlow()

    // Reactive observation of authenticated user from FirebaseAuthHelper
    val currentAuthUser: StateFlow<AuthUser?> = authHelper.currentAuthUser
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = authHelper.currentAuthUser.value
        )

    init {
        viewModelScope.launch {
            authHelper.currentAuthUser.collect { user ->
                _uiState.update { it.copy(currentUser = user) }
            }
        }
    }

    fun onFullNameChange(name: String) {
        _uiState.update { it.copy(fullName = name, errorMessage = null) }
    }

    fun onEmailChange(email: String) {
        _uiState.update { it.copy(email = email, errorMessage = null) }
    }

    fun onPhoneChange(phone: String) {
        _uiState.update { it.copy(phone = phone, errorMessage = null) }
    }

    fun onPasswordChange(password: String) {
        _uiState.update { it.copy(password = password, errorMessage = null) }
    }

    fun onConfirmPasswordChange(confirmPassword: String) {
        _uiState.update { it.copy(confirmPassword = confirmPassword, errorMessage = null) }
    }

    fun onRoleSelect(role: UserRole) {
        _uiState.update { it.copy(selectedRole = role) }
    }

    fun onAcceptTermsToggle(accept: Boolean) {
        _uiState.update { it.copy(acceptTerms = accept, errorMessage = null) }
    }

    fun toggleAuthMode() {
        _uiState.update {
            it.copy(
                isSignUpMode = !it.isSignUpMode,
                errorMessage = null,
                successMessage = null
            )
        }
    }

    fun setSignUpMode(isSignUp: Boolean) {
        _uiState.update {
            it.copy(
                isSignUpMode = isSignUp,
                errorMessage = null,
                successMessage = null
            )
        }
    }

    fun clearMessages() {
        _uiState.update {
            it.copy(errorMessage = null, successMessage = null)
        }
    }

    /**
     * Executes Email & Password Sign-in flow.
     */
    fun signIn() {
        viewModelScope.launch {
            executeSignIn()
        }
    }

    suspend fun executeSignIn(): FirebaseAuthResult<AuthUser> {
        val state = _uiState.value
        val email = state.email.trim()
        val password = state.password

        if (email.isBlank() || !android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            _uiState.update { it.copy(errorMessage = "Please enter a valid email address.") }
            return FirebaseAuthResult.Error("Please enter a valid email address.")
        }
        if (password.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Please enter your password.") }
            return FirebaseAuthResult.Error("Please enter your password.")
        }

        _uiState.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
        val result = authHelper.signInWithEmailAndPassword(email, password)
        when (result) {
            is FirebaseAuthResult.Success -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        currentUser = result.data,
                        successMessage = result.message ?: "Welcome back!"
                    )
                }
                _events.emit(AuthNavigationEvent.NavigateToHome(result.data.role))
            }
            is FirebaseAuthResult.Error -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = result.message
                    )
                }
            }
            is FirebaseAuthResult.Loading -> {
                _uiState.update { it.copy(isLoading = true) }
            }
        }
        return result
    }

    /**
     * Executes User Registration flow with email verification and display name update.
     */
    fun signUp() {
        viewModelScope.launch {
            executeSignUp()
        }
    }

    suspend fun executeSignUp(): FirebaseAuthResult<AuthUser> {
        val state = _uiState.value
        val fullName = state.fullName.trim()
        val email = state.email.trim()
        val phone = state.phone.trim()
        val password = state.password
        val confirmPassword = state.confirmPassword

        if (fullName.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Full name is required.") }
            return FirebaseAuthResult.Error("Full name is required.")
        }
        if (email.isBlank() || !android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            _uiState.update { it.copy(errorMessage = "Please enter a valid email address.") }
            return FirebaseAuthResult.Error("Please enter a valid email address.")
        }
        if (password.length < 6) {
            _uiState.update { it.copy(errorMessage = "Password must be at least 6 characters.") }
            return FirebaseAuthResult.Error("Password must be at least 6 characters.")
        }
        if (password != confirmPassword) {
            _uiState.update { it.copy(errorMessage = "Passwords do not match.") }
            return FirebaseAuthResult.Error("Passwords do not match.")
        }
        if (!state.acceptTerms) {
            _uiState.update { it.copy(errorMessage = "You must agree to the Terms and Conditions.") }
            return FirebaseAuthResult.Error("You must agree to the Terms and Conditions.")
        }

        _uiState.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
        val result = authHelper.signUpWithEmailAndPassword(
            email = email,
            password = password,
            fullName = fullName,
            phone = phone,
            role = state.selectedRole,
            sendVerificationEmail = true
        )
        when (result) {
            is FirebaseAuthResult.Success -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        currentUser = result.data,
                        isVerificationEmailSent = true,
                        successMessage = result.message ?: "Account created successfully!"
                    )
                }
                _events.emit(AuthNavigationEvent.NavigateToHome(result.data.role))
            }
            is FirebaseAuthResult.Error -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = result.message
                    )
                }
            }
            is FirebaseAuthResult.Loading -> {
                _uiState.update { it.copy(isLoading = true) }
            }
        }
        return result
    }

    /**
     * Executes Google Sign-in flow with Firebase AuthCredential.
     */
    fun signInWithGoogle(credential: AuthCredential, role: UserRole = _uiState.value.selectedRole) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            when (val result = authHelper.signInWithCredential(credential, role)) {
                is FirebaseAuthResult.Success -> {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            currentUser = result.data,
                            successMessage = result.message ?: "Google sign-in successful."
                        )
                    }
                    _events.emit(AuthNavigationEvent.NavigateToHome(result.data.role))
                }
                is FirebaseAuthResult.Error -> {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = result.message
                        )
                    }
                }
                is FirebaseAuthResult.Loading -> {
                    _uiState.update { it.copy(isLoading = true) }
                }
            }
        }
    }

    /**
     * Executes Google Sign-in flow with Google ID Token.
     */
    fun signInWithGoogleIdToken(idToken: String, role: UserRole = _uiState.value.selectedRole) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            when (val result = authHelper.signInWithGoogleIdToken(idToken = idToken, role = role)) {
                is FirebaseAuthResult.Success -> {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            currentUser = result.data,
                            successMessage = result.message ?: "Google sign-in successful."
                        )
                    }
                    _events.emit(AuthNavigationEvent.NavigateToHome(result.data.role))
                }
                is FirebaseAuthResult.Error -> {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = result.message
                        )
                    }
                }
                is FirebaseAuthResult.Loading -> {
                    _uiState.update { it.copy(isLoading = true) }
                }
            }
        }
    }

    /**
     * Sends password reset email instructions.
     */
    fun sendPasswordReset(email: String = _uiState.value.email) {
        viewModelScope.launch {
            executePasswordReset(email)
        }
    }

    suspend fun executePasswordReset(email: String = _uiState.value.email): FirebaseAuthResult<Unit> {
        val targetEmail = email.trim()
        if (targetEmail.isBlank() || !android.util.Patterns.EMAIL_ADDRESS.matcher(targetEmail).matches()) {
            _uiState.update { it.copy(errorMessage = "Please enter a valid email address.") }
            return FirebaseAuthResult.Error("Please enter a valid email address.")
        }

        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        val result = authHelper.sendPasswordResetEmail(targetEmail)
        when (result) {
            is FirebaseAuthResult.Success -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isPasswordResetSent = true,
                        successMessage = result.message ?: "Password reset instructions dispatched."
                    )
                }
                _events.emit(AuthNavigationEvent.ShowToast("Password reset email sent to $targetEmail"))
            }
            is FirebaseAuthResult.Error -> {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = result.message
                    )
                }
            }
            is FirebaseAuthResult.Loading -> {
                _uiState.update { it.copy(isLoading = true) }
            }
        }
        return result
    }

    /**
     * Signs out the user.
     */
    fun signOut() {
        authHelper.signOut()
        _uiState.update {
            it.copy(
                currentUser = null,
                password = "",
                confirmPassword = "",
                successMessage = "Signed out successfully."
            )
        }
    }
}
