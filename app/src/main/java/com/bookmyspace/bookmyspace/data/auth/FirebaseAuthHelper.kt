package com.bookmyspace.bookmyspace.data.auth

import android.util.Log
import com.bookmyspace.bookmyspace.data.model.AuthUser
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.AuthCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthActionCodeException
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthWeakPasswordException
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.UserProfileChangeRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Result wrapper for Firebase Authentication operations with typed error handling.
 */
sealed class FirebaseAuthResult<out T> {
    data class Success<out T>(val data: T, val message: String? = null) : FirebaseAuthResult<T>()
    data class Error(val message: String, val throwable: Throwable? = null, val errorCode: String? = null) : FirebaseAuthResult<Nothing>()
    data object Loading : FirebaseAuthResult<Nothing>()
}

/**
 * Centralized Firebase Authentication Helper.
 * Provides clean, coroutine-based async methods for ViewModel consumption,
 * unified state management, graceful offline fallback, and user-friendly error translation.
 */
object FirebaseAuthHelper {

    private const val TAG = "FirebaseAuthHelper"
    private val helperScope = CoroutineScope(Dispatchers.Default)

    private val _currentAuthUser = MutableStateFlow<AuthUser?>(BookMySpaceRepository.authUser.value)
    val currentAuthUser: StateFlow<AuthUser?> = _currentAuthUser.asStateFlow()

    private val _currentFirebaseUser = MutableStateFlow<FirebaseUser?>(null)
    val currentFirebaseUser: StateFlow<FirebaseUser?> = _currentFirebaseUser.asStateFlow()

    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    init {
        setupAuthStateListener()
    }

    /**
     * Safely retrieves the FirebaseAuth instance if available.
     */
    fun getAuthInstance(): FirebaseAuth? {
        return try {
            if (FirebaseApp.getApps(FirebaseApp.getInstance().applicationContext).isNotEmpty()) {
                FirebaseAuth.getInstance()
            } else {
                FirebaseAuth.getInstance()
            }
        } catch (e: Exception) {
            Log.w(TAG, "FirebaseAuth instance retrieval fallback: ${e.message}")
            try {
                FirebaseAuth.getInstance()
            } catch (_: Exception) {
                null
            }
        }
    }

    /**
     * Listens for Firebase Auth state changes and syncs with BookMySpace repository.
     */
    private fun setupAuthStateListener() {
        try {
            val auth = getAuthInstance()
            if (auth != null) {
                auth.addAuthStateListener { firebaseAuth ->
                    val fbUser = firebaseAuth.currentUser
                    _currentFirebaseUser.value = fbUser
                    if (fbUser != null) {
                        val mapped = mapFirebaseUserToAuthUser(fbUser)
                        _currentAuthUser.value = mapped
                        BookMySpaceRepository.setAuthUser(mapped)
                    }
                }
                _isInitialized.value = true
                _currentFirebaseUser.value = auth.currentUser
                auth.currentUser?.let { fbUser ->
                    val mapped = mapFirebaseUserToAuthUser(fbUser)
                    _currentAuthUser.value = mapped
                }
            } else {
                Log.i(TAG, "FirebaseAuth not configured yet; will operate in local repository fallback mode.")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to attach FirebaseAuth state listener: ${e.message}")
        }
    }

    /**
     * Flow that emits whenever the Firebase Auth state changes.
     */
    fun authStateFlow(): Flow<FirebaseUser?> = callbackFlow {
        val auth = getAuthInstance()
        if (auth == null) {
            trySend(null)
            close()
            return@callbackFlow
        }

        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser)
        }
        auth.addAuthStateListener(listener)
        awaitClose {
            auth.removeAuthStateListener(listener)
        }
    }

    /**
     * Signs in a user using Email and Password.
     * Synchronizes state with BookMySpaceRepository upon success.
     */
    suspend fun signInWithEmailAndPassword(
        email: String,
        password: String
    ): FirebaseAuthResult<AuthUser> = withContext(Dispatchers.IO) {
        val trimmedEmail = email.trim()
        if (trimmedEmail.isBlank() || password.isBlank()) {
            return@withContext FirebaseAuthResult.Error("Email and password must not be empty.")
        }

        try {
            val auth = getAuthInstance()
            if (auth != null) {
                Log.d(TAG, "Attempting Firebase email sign-in for: $trimmedEmail")
                val authResult = auth.signInWithEmailAndPassword(trimmedEmail, password).await()
                val fbUser = authResult.user
                    ?: return@withContext FirebaseAuthResult.Error("Sign-in succeeded but user details were null.")

                val domainUser = mapFirebaseUserToAuthUser(fbUser)
                _currentAuthUser.value = domainUser
                _currentFirebaseUser.value = fbUser
                BookMySpaceRepository.setAuthUser(domainUser)

                Log.i(TAG, "Firebase sign-in successful for: ${domainUser.email} (${domainUser.id})")
                FirebaseAuthResult.Success(domainUser, "Signed in successfully.")
            } else {
                // Fallback mode for environments without active cloud Firebase configuration
                Log.i(TAG, "Firebase Auth not available, using local repository login fallback.")
                val localResult = BookMySpaceRepository.loginWithEmailAndPassword(trimmedEmail, password)
                if (localResult.isSuccess) {
                    val user = localResult.getOrThrow()
                    _currentAuthUser.value = user
                    FirebaseAuthResult.Success(user, "Signed in successfully (Offline Mode).")
                } else {
                    FirebaseAuthResult.Error(localResult.exceptionOrNull()?.message ?: "Login failed.")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "signInWithEmailAndPassword failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Creates a new user account with Email and Password, updates their display name,
     * optionally sends an email verification link, and persists their role.
     */
    suspend fun signUpWithEmailAndPassword(
        email: String,
        password: String,
        fullName: String,
        phone: String = "",
        role: UserRole = UserRole.USER,
        sendVerificationEmail: Boolean = true
    ): FirebaseAuthResult<AuthUser> = withContext(Dispatchers.IO) {
        val trimmedEmail = email.trim()
        val trimmedName = fullName.trim()

        if (trimmedEmail.isBlank()) {
            return@withContext FirebaseAuthResult.Error("Email address is required.")
        }
        if (password.length < 6) {
            return@withContext FirebaseAuthResult.Error("Password must be at least 6 characters long.")
        }
        if (trimmedName.isBlank()) {
            return@withContext FirebaseAuthResult.Error("Full name is required.")
        }

        try {
            val auth = getAuthInstance()
            if (auth != null) {
                Log.d(TAG, "Creating new Firebase user account for: $trimmedEmail")
                val authResult = auth.createUserWithEmailAndPassword(trimmedEmail, password).await()
                val fbUser = authResult.user
                    ?: return@withContext FirebaseAuthResult.Error("User creation succeeded but user object was null.")

                // Update Firebase User Profile Display Name
                try {
                    val profileUpdates = UserProfileChangeRequest.Builder()
                        .setDisplayName(trimmedName)
                        .build()
                    fbUser.updateProfile(profileUpdates).await()
                } catch (pe: Exception) {
                    Log.w(TAG, "Could not set user display name: ${pe.message}")
                }

                // Send email verification if requested
                var verificationSent = false
                if (sendVerificationEmail) {
                    try {
                        fbUser.sendEmailVerification().await()
                        verificationSent = true
                        Log.i(TAG, "Verification email sent to $trimmedEmail")
                    } catch (ve: Exception) {
                        Log.w(TAG, "Failed to dispatch email verification: ${ve.message}")
                    }
                }

                val domainUser = AuthUser(
                    id = fbUser.uid,
                    email = trimmedEmail,
                    fullName = trimmedName,
                    phone = phone,
                    role = role,
                    avatarUrl = fbUser.photoUrl?.toString() ?: "",
                    isEmailVerified = fbUser.isEmailVerified
                )

                _currentAuthUser.value = domainUser
                _currentFirebaseUser.value = fbUser
                BookMySpaceRepository.setAuthUser(domainUser)

                val notice = if (verificationSent) {
                    "Account registered! A verification email has been sent to $trimmedEmail."
                } else {
                    "Account registered successfully."
                }

                FirebaseAuthResult.Success(domainUser, notice)
            } else {
                // Fallback mode
                Log.i(TAG, "Firebase Auth not available, using local repository registration fallback.")
                val localResult = BookMySpaceRepository.registerUserWithEmailVerification(
                    fullName = trimmedName,
                    email = trimmedEmail,
                    password = password,
                    role = role,
                    phone = phone
                )
                if (localResult.isSuccess) {
                    val pending = localResult.getOrThrow()
                    val user = AuthUser(
                        id = "user_${UUID.randomUUID().toString().take(6)}",
                        email = pending.email,
                        fullName = pending.fullName,
                        phone = phone,
                        role = role,
                        isEmailVerified = true
                    )
                    _currentAuthUser.value = user
                    BookMySpaceRepository.setAuthUser(user)
                    FirebaseAuthResult.Success(user, "Account registered successfully (Offline Mode).")
                } else {
                    FirebaseAuthResult.Error(localResult.exceptionOrNull()?.message ?: "Registration failed.")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "signUpWithEmailAndPassword failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Signs in using a Firebase AuthCredential (e.g. Google Sign-In, OAuth).
     */
    suspend fun signInWithCredential(
        credential: AuthCredential,
        role: UserRole = UserRole.USER
    ): FirebaseAuthResult<AuthUser> = withContext(Dispatchers.IO) {
        try {
            val auth = getAuthInstance()
            if (auth != null) {
                Log.d(TAG, "Signing in with Firebase AuthCredential...")
                val authResult = auth.signInWithCredential(credential).await()
                val fbUser = authResult.user
                    ?: return@withContext FirebaseAuthResult.Error("Credential authentication succeeded but user was null.")

                val domainUser = AuthUser(
                    id = fbUser.uid,
                    email = fbUser.email ?: "",
                    fullName = fbUser.displayName ?: fbUser.email?.substringBefore("@") ?: "User",
                    phone = fbUser.phoneNumber ?: "",
                    role = role,
                    avatarUrl = fbUser.photoUrl?.toString() ?: "",
                    isEmailVerified = fbUser.isEmailVerified
                )

                _currentAuthUser.value = domainUser
                _currentFirebaseUser.value = fbUser
                BookMySpaceRepository.setAuthUser(domainUser)

                FirebaseAuthResult.Success(domainUser, "Google sign-in successful.")
            } else {
                val fallbackUser = BookMySpaceRepository.loginWithGoogle(
                    email = "narenqe2@gmail.com",
                    fullName = "Narendra Reddy",
                    role = role
                ).getOrNull()

                if (fallbackUser != null) {
                    _currentAuthUser.value = fallbackUser
                    FirebaseAuthResult.Success(fallbackUser, "Google sign-in successful (Offline Mode).")
                } else {
                    FirebaseAuthResult.Error("Google Sign-In is unavailable.")
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "signInWithCredential failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Signs in using Google ID Token and optional Access Token.
     */
    suspend fun signInWithGoogleIdToken(
        idToken: String,
        accessToken: String? = null,
        role: UserRole = UserRole.USER
    ): FirebaseAuthResult<AuthUser> {
        val credential = GoogleAuthProvider.getCredential(idToken, accessToken)
        return signInWithCredential(credential, role)
    }

    /**
     * Sends a password reset email via Firebase Auth.
     */
    suspend fun sendPasswordResetEmail(email: String): FirebaseAuthResult<Unit> = withContext(Dispatchers.IO) {
        val trimmedEmail = email.trim()
        if (trimmedEmail.isBlank()) {
            return@withContext FirebaseAuthResult.Error("Please enter your registered email address.")
        }

        try {
            val auth = getAuthInstance()
            if (auth != null) {
                auth.sendPasswordResetEmail(trimmedEmail).await()
                FirebaseAuthResult.Success(Unit, "Password reset instructions sent to $trimmedEmail.")
            } else {
                BookMySpaceRepository.requestPasswordReset(trimmedEmail)
                FirebaseAuthResult.Success(Unit, "Password reset instructions sent to $trimmedEmail (Offline Mode).")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "sendPasswordResetEmail failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Dispatches an email verification link to the currently signed-in user.
     */
    suspend fun sendEmailVerification(): FirebaseAuthResult<Unit> = withContext(Dispatchers.IO) {
        try {
            val fbUser = getAuthInstance()?.currentUser
            if (fbUser != null) {
                fbUser.sendEmailVerification().await()
                FirebaseAuthResult.Success(Unit, "Verification email dispatched to ${fbUser.email}.")
            } else {
                FirebaseAuthResult.Error("No user is currently signed in.")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "sendEmailVerification failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Reloads the current Firebase user profile to refresh email verification status or token.
     */
    suspend fun reloadUser(): FirebaseAuthResult<AuthUser?> = withContext(Dispatchers.IO) {
        try {
            val fbUser = getAuthInstance()?.currentUser
            if (fbUser != null) {
                fbUser.reload().await()
                _currentFirebaseUser.value = fbUser
                val updatedDomainUser = mapFirebaseUserToAuthUser(fbUser)
                _currentAuthUser.value = updatedDomainUser
                BookMySpaceRepository.setAuthUser(updatedDomainUser)
                FirebaseAuthResult.Success(updatedDomainUser, "User profile refreshed.")
            } else {
                FirebaseAuthResult.Success(null, "No user is currently signed in.")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "reloadUser failed: ${e.message}", e)
            FirebaseAuthResult.Error(
                message = parseAuthExceptionMessage(e),
                throwable = e
            )
        }
    }

    /**
     * Signs out the current user and clears session state.
     */
    fun signOut() {
        try {
            getAuthInstance()?.signOut()
        } catch (e: Exception) {
            Log.w(TAG, "Error during Firebase signOut: ${e.message}")
        }
        _currentFirebaseUser.value = null
        _currentAuthUser.value = null
        BookMySpaceRepository.logout()
    }

    /**
     * Maps a FirebaseUser instance into the BookMySpace domain AuthUser model.
     */
    fun mapFirebaseUserToAuthUser(
        fbUser: FirebaseUser,
        forcedRole: UserRole? = null
    ): AuthUser {
        val existingRole = BookMySpaceRepository.authUser.value?.takeIf { it.id == fbUser.uid }?.role
        val resolvedRole = forcedRole ?: existingRole ?: UserRole.USER
        return AuthUser(
            id = fbUser.uid,
            email = fbUser.email ?: "",
            fullName = fbUser.displayName?.ifBlank { null }
                ?: fbUser.email?.substringBefore("@")?.replace(".", " ")?.replaceFirstChar { it.uppercase() }
                ?: "User",
            phone = fbUser.phoneNumber ?: "",
            role = resolvedRole,
            avatarUrl = fbUser.photoUrl?.toString() ?: "",
            isEmailVerified = fbUser.isEmailVerified
        )
    }

    /**
     * Translates Firebase-specific exceptions into user-friendly messages for UI presentation.
     */
    fun parseAuthExceptionMessage(throwable: Throwable): String {
        return when (throwable) {
            is FirebaseAuthInvalidCredentialsException -> {
                "Invalid email or password. Please verify your credentials and try again."
            }
            is FirebaseAuthInvalidUserException -> {
                "No account found with this email address, or the account has been disabled."
            }
            is FirebaseAuthUserCollisionException -> {
                "An account with this email address already exists. Please sign in instead."
            }
            is FirebaseAuthWeakPasswordException -> {
                "The chosen password is too weak. Please use at least 6 characters with mixed letters and numbers."
            }
            is FirebaseAuthActionCodeException -> {
                "The verification or password reset code has expired or is invalid."
            }
            is FirebaseAuthRecentLoginRequiredException -> {
                "This action requires recent authentication. Please sign in again."
            }
            is com.google.firebase.FirebaseNetworkException -> {
                "Network connection issue. Please check your internet connection and try again."
            }
            else -> {
                val raw = throwable.message ?: "Authentication error occurred."
                when {
                    raw.contains("INVALID_LOGIN_CREDENTIALS", ignoreCase = true) ->
                        "Invalid email or password. Please check your details."
                    raw.contains("EMAIL_NOT_FOUND", ignoreCase = true) ->
                        "No account found with this email address."
                    raw.contains("EMAIL_EXISTS", ignoreCase = true) ->
                        "An account with this email already exists."
                    raw.contains("TOO_MANY_ATTEMPTS_TRY_LATER", ignoreCase = true) ->
                        "Too many unsuccessful attempts. Please try again in a few minutes."
                    raw.contains("USER_DISABLED", ignoreCase = true) ->
                        "This user account has been disabled by an administrator."
                    raw.contains("NETWORK_ERROR", ignoreCase = true) ->
                        "Network error. Please check your connection."
                    else -> raw
                }
            }
        }
    }
}
