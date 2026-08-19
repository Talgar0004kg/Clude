package ai.arena.grokkeyboard.ime

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Toast
import androidx.core.content.ContextCompat
import ai.arena.grokkeyboard.audio.AudioRecorderManager
import ai.arena.grokkeyboard.data.GrokApiClient
import ai.arena.grokkeyboard.data.GrokModelManager
import ai.arena.grokkeyboard.data.SecureSettings
import ai.arena.grokkeyboard.settings.SettingsActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File

class GrokKeyboardService : InputMethodService(), IosKeyboardView.Listener {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var keyboard: IosKeyboardView
    private lateinit var recorder: AudioRecorderManager
    private lateinit var secure: SecureSettings
    private val api = GrokApiClient()
    private var transcriptionJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        secure = SecureSettings(this)
        recorder = AudioRecorderManager(this)
    }

    override fun onCreateInputView(): View = IosKeyboardView(this, this).also { keyboard = it }
    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        if (::keyboard.isInitialized && recorder.state.value !is AudioRecorderManager.State.Recording) keyboard.showIdle()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        recorder.cancel()
        transcriptionJob?.cancel()
        transcriptionJob = null
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        recorder.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onText(text: String) {
        currentInputConnection?.commitText(text, 1)
    }

    override fun onBackspace() {
        currentInputConnection?.let { connection ->
            if (!connection.deleteSurroundingText(1, 0)) {
                connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
                connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
            }
        }
    }

    override fun onEnter() {
        val action = currentInputEditorInfo?.imeOptions?.and(EditorInfo.IME_MASK_ACTION)
        if (action != null && action != EditorInfo.IME_ACTION_NONE && action != EditorInfo.IME_ACTION_UNSPECIFIED) {
            currentInputConnection?.performEditorAction(action)
        } else {
            currentInputConnection?.commitText("\n", 1)
        }
    }

    override fun onSwitchKeyboard() {
        val canSwitch = android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.P ||
            shouldOfferSwitchingToNextInputMethod()
        if (canSwitch && switchToNextInputMethod(false)) return
        (getSystemService(INPUT_METHOD_SERVICE) as? android.view.inputmethod.InputMethodManager)
            ?.showInputMethodPicker()
    }

    override fun onMicrophone() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "Grant microphone access in Grok Keyboard settings", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, SettingsActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        }
        if (secure.apiKey.isBlank()) {
            Toast.makeText(this, "Add your Grok API key in keyboard settings", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, SettingsActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        }
        when (recorder.state.value) {
            is AudioRecorderManager.State.Recording -> stopAndTranscribe()
            is AudioRecorderManager.State.Processing -> Unit
            else -> recorder.start().onSuccess { keyboard.showRecording() }
                .onFailure { keyboard.showError(it.message ?: "Microphone unavailable") }
        }
    }

    private fun stopAndTranscribe() {
        recorder.stop()
            .onSuccess { file ->
                keyboard.showProcessing()
                transcriptionJob = serviceScope.launch { transcribe(file) }
            }
            .onFailure { keyboard.showError(it.message ?: "Recording failed") }
    }

    private suspend fun transcribe(audio: File) {
        try {
            // Model discovery is authenticated and refreshed for each request; network errors use the stable fallback.
            val model = GrokModelManager(api, secure).refreshOrFallback()
            val text = api.transcribe(secure.apiKey, model, secure.systemPrompt, audio)
            commitTranscription(text)
            keyboard.showIdle()
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            keyboard.showError(error.message ?: "Transcription failed")
            Toast.makeText(this, error.message ?: "Transcription failed", Toast.LENGTH_LONG).show()
        } finally {
            audio.delete()
            recorder.markIdle()
            transcriptionJob = null
        }
    }

    private fun commitTranscription(raw: String) {
        val connection = currentInputConnection ?: return
        val text = raw.trim()
        if (text.isEmpty()) return
        val before = connection.getTextBeforeCursor(1, 0)?.lastOrNull()
        val after = connection.getTextAfterCursor(1, 0)?.firstOrNull()
        val punctuation = ".,!?;:)]}"
        val prefix = if (before != null && !before.isWhitespace() && text.first() !in punctuation) " " else ""
        val suffix = if (after == null || (!after.isWhitespace() && after !in punctuation)) " " else ""
        connection.beginBatchEdit()
        try {
            connection.commitText(prefix + text + suffix, 1)
        } finally {
            connection.endBatchEdit()
        }
    }
}
