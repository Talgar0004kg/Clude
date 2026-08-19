package ai.arena.grokkeyboard.audio

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File

class AudioRecorderManager(private val context: Context) {
    sealed interface State {
        data object Idle : State
        data class Recording(val startedAtMillis: Long) : State
        data object Processing : State
        data class Error(val message: String) : State
    }

    private val mutableState = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = mutableState.asStateFlow()
    private var recorder: MediaRecorder? = null
    private var output: File? = null

    @Synchronized
    fun start(): Result<Unit> = runCatching {
        check(recorder == null) { "A recording is already active" }
        val target = File(context.cacheDir, "voice_${System.currentTimeMillis()}.m4a")
        val mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION") MediaRecorder()
        }
        try {
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioChannels(1)
            mediaRecorder.setAudioSamplingRate(16_000)
            mediaRecorder.setAudioEncodingBitRate(32_000)
            mediaRecorder.setOutputFile(target.absolutePath)
            mediaRecorder.prepare()
            mediaRecorder.start()
            recorder = mediaRecorder
            output = target
            mutableState.value = State.Recording(System.currentTimeMillis())
        } catch (error: Throwable) {
            mediaRecorder.release()
            target.delete()
            throw error
        }
    }.onFailure { mutableState.value = State.Error(it.message ?: "Could not start microphone") }

    @Synchronized
    fun stop(): Result<File> {
        val active = recorder ?: return Result.failure(IllegalStateException("No recording is active"))
        val file = checkNotNull(output)
        recorder = null
        output = null
        return runCatching {
            try {
                active.stop()
            } finally {
                active.release()
            }
            check(file.length() > 512) { "Recording was too short" }
            mutableState.value = State.Processing
            file
        }.onFailure {
            file.delete()
            mutableState.value = State.Error(it.message ?: "Could not finish recording")
        }
    }

    @Synchronized
    fun cancel() {
        recorder?.runCatching { stop() }
        recorder?.release()
        recorder = null
        output?.delete()
        output = null
        mutableState.value = State.Idle
    }

    fun markIdle() { mutableState.value = State.Idle }
}
