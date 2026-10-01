package com.bookmyspace.bookmyspace.data.model

data class FirebaseAnalyticsEvent(
    val name: String,
    val params: Map<String, String> = emptyMap(),
    val category: String = "general",
    val timestamp: String = "Just now"
)
