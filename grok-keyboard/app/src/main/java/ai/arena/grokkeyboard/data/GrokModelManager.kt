package ai.arena.grokkeyboard.data

class GrokModelManager(
    private val api: GrokApiClient,
    private val settings: SecureSettings
) {
    /** Returns speech-capable models newest-first and persists the best candidate. */
    suspend fun refresh(apiKey: String = settings.apiKey): List<GrokApiClient.Model> {
        val speechModels = api.models(apiKey)
            .filter { model -> AUDIO_HINTS.any { model.id.contains(it, ignoreCase = true) } }
            .sortedWith(compareByDescending<GrokApiClient.Model> { it.created }.thenByDescending { it.id })
        settings.selectedModel = speechModels.firstOrNull()?.id ?: SecureSettings.FALLBACK_MODEL
        return speechModels
    }

    /** Discovery failures never prevent recording; the documented fallback remains usable. */
    suspend fun refreshOrFallback(): String = runCatching {
        refresh().firstOrNull()?.id ?: SecureSettings.FALLBACK_MODEL
    }.getOrDefault(SecureSettings.FALLBACK_MODEL).also { settings.selectedModel = it }

    companion object {
        private val AUDIO_HINTS = listOf("audio", "stt", "speech", "transcri", "whisper")
    }
}
