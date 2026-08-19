package ai.arena.grokkeyboard.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import ai.arena.grokkeyboard.R

class SecureSettings(context: Context) {
    private val appContext = context.applicationContext
    private val preferences by lazy {
        val key = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            appContext,
            "grok_secure_settings",
            key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    var apiKey: String
        get() = preferences.getString(KEY_API_KEY, "").orEmpty()
        set(value) = preferences.edit().putString(KEY_API_KEY, value.trim()).apply()

    var systemPrompt: String
        get() = preferences.getString(KEY_PROMPT, null)
            ?: appContext.getString(R.string.default_prompt)
        set(value) = preferences.edit().putString(KEY_PROMPT, value.trim()).apply()

    var selectedModel: String
        get() = preferences.getString(KEY_MODEL, FALLBACK_MODEL) ?: FALLBACK_MODEL
        set(value) = preferences.edit().putString(KEY_MODEL, value).apply()

    companion object {
        const val FALLBACK_MODEL = "grok-2-audio"
        private const val KEY_API_KEY = "api_key"
        private const val KEY_PROMPT = "system_prompt"
        private const val KEY_MODEL = "selected_model"
    }
}
