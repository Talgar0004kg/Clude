package ai.arena.grokkeyboard.settings

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.preference.EditTextPreference
import androidx.preference.Preference
import androidx.preference.PreferenceCategory
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.PreferenceScreen
import ai.arena.grokkeyboard.data.GrokApiClient
import ai.arena.grokkeyboard.data.GrokModelManager
import ai.arena.grokkeyboard.data.SecureSettings
import kotlinx.coroutines.launch

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, SettingsFragment())
                .commit()
        }
    }
}

class SettingsFragment : PreferenceFragmentCompat() {
    private lateinit var secure: SecureSettings
    private lateinit var apiKeyPreference: EditTextPreference
    private lateinit var modelPreference: Preference
    private lateinit var testPreference: Preference

    private val requestAudio = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        toast(if (granted) "Microphone access granted" else "Microphone access is required for voice typing")
    }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        secure = SecureSettings(requireContext())
        preferenceScreen = preferenceManager.createPreferenceScreen(requireContext()).apply {
            title = "Grok Keyboard settings"
            addPreference(setupCategory())
            addPreference(voiceCategory())
        }
    }

    private fun setupCategory(): PreferenceCategory = PreferenceCategory(requireContext()).apply {
        title = "Keyboard setup"
        addPreference(Preference(requireContext()).apply {
            title = "1. Enable Grok Keyboard"
            summary = "Open Android keyboard settings"
            setOnPreferenceClickListener {
                startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)); true
            }
        })
        addPreference(Preference(requireContext()).apply {
            title = "2. Select Grok Keyboard"
            summary = "Show the keyboard picker"
            setOnPreferenceClickListener {
                ContextCompat.getSystemService(requireContext(), InputMethodManager::class.java)
                    ?.showInputMethodPicker(); true
            }
        })
        addPreference(Preference(requireContext()).apply {
            title = "3. Allow microphone"
            summary = permissionSummary()
            setOnPreferenceClickListener {
                requestAudio.launch(Manifest.permission.RECORD_AUDIO); true
            }
        })
    }

    private fun voiceCategory(): PreferenceCategory = PreferenceCategory(requireContext()).apply {
        title = "xAI voice transcription"
        apiKeyPreference = EditTextPreference(requireContext()).apply {
            title = "Grok API key"
            isPersistent = false // Never write secrets to PreferenceManager's plain-text store.
            text = secure.apiKey
            summary = keySummary(secure.apiKey)
            dialogTitle = "Grok API key"
            setOnBindEditTextListener { field ->
                field.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                field.setSelection(field.text.length)
            }
            setOnPreferenceChangeListener { preference, newValue ->
                val value = newValue.toString().trim()
                secure.apiKey = value
                (preference as EditTextPreference).summary = keySummary(value)
                true
            }
        }
        addPreference(apiKeyPreference)
        addPreference(EditTextPreference(requireContext()).apply {
            title = "System prompt"
            isPersistent = false
            text = secure.systemPrompt
            summary = secure.systemPrompt
            dialogTitle = "Transcription instructions"
            setOnBindEditTextListener { field ->
                field.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
                field.minLines = 4
            }
            setOnPreferenceChangeListener { preference, newValue ->
                val value = newValue.toString().trim()
                if (value.isBlank()) return@setOnPreferenceChangeListener false
                secure.systemPrompt = value
                preference.summary = value
                true
            }
        })
        modelPreference = Preference(requireContext()).apply {
            title = "Selected audio model"
            summary = secure.selectedModel
            isSelectable = false
        }
        addPreference(modelPreference)
        testPreference = Preference(requireContext()).apply {
            title = "Test connection & fetch models"
            summary = "Discover the newest speech-capable xAI model"
            setOnPreferenceClickListener { testConnection(); true }
        }
        addPreference(testPreference)
        addPreference(Preference(requireContext()).apply {
            title = "Privacy"
            summary = "Audio is stored only in the app cache, uploaded to api.x.ai over HTTPS, then deleted. API credentials are encrypted with Android Keystore."
            isSelectable = false
        })
    }

    private fun testConnection() {
        if (secure.apiKey.isBlank()) {
            toast("Enter an API key first")
            return
        }
        testPreference.isEnabled = false
        testPreference.summary = "Connecting…"
        viewLifecycleOwner.lifecycleScope.launch {
            runCatching { GrokModelManager(GrokApiClient(), secure).refresh() }
                .onSuccess { models ->
                    modelPreference.summary = secure.selectedModel
                    testPreference.summary = if (models.isEmpty()) {
                        "Connected; no audio model advertised. Using ${secure.selectedModel}"
                    } else "Found ${models.size}: ${models.joinToString { it.id }}"
                    toast("Connection successful")
                }
                .onFailure {
                    testPreference.summary = it.message ?: "Connection failed"
                    toast("Connection failed")
                }
            testPreference.isEnabled = true
        }
    }

    private fun permissionSummary(): String = if (
        ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    ) "Granted" else "Required for voice typing"

    private fun keySummary(value: String) = if (value.isBlank()) "Not configured" else "••••••••${value.takeLast(4)}"
    private fun toast(message: String) = Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
}
