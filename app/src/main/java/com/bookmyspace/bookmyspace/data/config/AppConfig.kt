package com.bookmyspace.bookmyspace.data.config

object AppConfig {
    const val supabaseUrl: String = "https://zykxneztahxbjduagutv.supabase.co"
    const val supabasePublishableKey: String = "sb_publishable_dev_key"
    const val razorpayKeyId: String = "rzp_test_bookmyspace"
    const val projectRef: String = "zykxneztahxbjduagutv"
    const val expectedProjectName: String = "bookmyspace-dev"

    val isDevConfigured: Boolean
        get() = supabaseUrl.contains("zykxneztahxbjduagutv")
}

