package ai.arena.grokkeyboard.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class GrokApiClient(
    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(90, TimeUnit.SECONDS)
        .callTimeout(120, TimeUnit.SECONDS)
        .build()
) {
    data class Model(val id: String, val created: Long = 0L)

    suspend fun models(apiKey: String): List<Model> = withContext(Dispatchers.IO) {
        require(apiKey.isNotBlank()) { "Add an xAI API key first" }
        val request = Request.Builder()
            .url("$BASE_URL/models")
            .header("Authorization", "Bearer $apiKey")
            .get()
            .build()
        http.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw apiError(response.code, body)
            val data = JSONObject(body).optJSONArray("data") ?: return@use emptyList()
            buildList {
                for (index in 0 until data.length()) {
                    val item = data.optJSONObject(index) ?: continue
                    val id = item.optString("id")
                    if (id.isNotBlank()) add(Model(id, item.optLong("created", 0L)))
                }
            }
        }
    }

    suspend fun transcribe(
        apiKey: String,
        model: String,
        prompt: String,
        audioFile: File
    ): String = withContext(Dispatchers.IO) {
        require(apiKey.isNotBlank()) { "Grok API key is missing" }
        require(audioFile.exists() && audioFile.length() > 0) { "No audio was recorded" }
        val multipart = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("model", model)
            .addFormDataPart("prompt", prompt)
            .addFormDataPart("response_format", "json")
            .addFormDataPart(
                "file",
                audioFile.name,
                audioFile.asRequestBody("audio/mp4".toMediaType())
            )
            .build()
        val request = Request.Builder()
            .url("$BASE_URL/audio/transcriptions")
            .header("Authorization", "Bearer $apiKey")
            .post(multipart)
            .build()
        http.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw apiError(response.code, body)
            JSONObject(body).optString("text").takeIf { it.isNotBlank() }
                ?: throw IOException("The API returned an empty transcription")
        }
    }

    private fun apiError(code: Int, body: String): IOException {
        val message = runCatching {
            JSONObject(body).optJSONObject("error")?.optString("message")
        }.getOrNull().takeUnless { it.isNullOrBlank() } ?: body.take(300)
        return IOException("xAI request failed ($code): $message")
    }

    companion object { private const val BASE_URL = "https://api.x.ai/v1" }
}
