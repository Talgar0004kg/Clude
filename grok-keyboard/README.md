# Grok Voice Keyboard for Android

A native Kotlin IME with an iOS-inspired adaptive keyboard and xAI-powered multilingual voice transcription.

## Architecture

- `GrokKeyboardService` — Android IME lifecycle, key events, voice state, smart transcription insertion.
- `IosKeyboardView` — light/dark rounded keyboard, one-shot shift, symbols, haptics, tap animations, and a microphone in the lower accessory inset.
- `AudioRecorderManager` — lifecycle-safe mono 16 kHz / 32 kbps AAC-in-M4A capture with observable state.
- `GrokApiClient` — authenticated OkHttp models and multipart transcription calls.
- `GrokModelManager` — discovers speech/audio/STT models, chooses newest by API `created`, and falls back to `grok-2-audio`.
- `SettingsActivity` — IME onboarding, runtime microphone permission, encrypted credentials and prompt, connection/model test.

## Build

Open `grok-keyboard/` in Android Studio (JDK 17, Android SDK 35) and run the `app` configuration. The repository does not commit generated build outputs or credentials.

After installation:

1. Open **Grok Voice Keyboard**.
2. Enable it under Android's input-method settings.
3. Select it as the current keyboard.
4. Grant microphone permission and enter an xAI API key.
5. Use **Test connection & fetch models** before voice typing.

## API contract

The app uses `GET https://api.x.ai/v1/models` and sends AAC/M4A as multipart form data to `POST https://api.x.ai/v1/audio/transcriptions` with `file`, `model`, `prompt`, and `response_format=json`. Model availability is account-dependent. If xAI changes its audio endpoint or does not expose an audio model to an account, the settings screen surfaces the API error without retaining audio.

## Security and privacy

The API key and prompt are stored in `EncryptedSharedPreferences` backed by Android Keystore. Android backup is disabled. Recordings live only in internal cache, use HTTPS, and are deleted after success, failure, or cancellation. No key is compiled into the APK.
