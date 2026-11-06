<div align="right"><b>English</b> | <a href="README.zh-CN.md">简体中文</a></div>

# ✨ Twinkle

AI-powered Chinese ⇄ English translator for **Mac, iPhone and Apple Watch**. Every result is shown side by side — original on top, translation below — with real-time voice translation on the phone.

## Features

- **Bilingual view** – original and translation shown together in one card, streamed token by token.
- **Direction control** – Auto-detect, 中→英, or 英→中.
- **Real-time voice translation** (Mac / iPhone) – speak Chinese or English; partial speech is translated live (debounced), and the final sentence is saved to history.
- **Read aloud** – two engines, switchable in Settings:
  - *System voices* (offline): pick a specific Chinese and English voice, including Enhanced / Premium ones.
  - *OpenAI cloud TTS*: more natural voices; falls back to system voices on failure.
  - Speed control and one-tap preview for both.
- **Bring your own LLM** – Anthropic (Claude) or any OpenAI-compatible API (OpenAI, DeepSeek, Qwen, local gateways…). After you enter an API key the model list is fetched automatically into a dropdown.
- **Apple Watch** – dictate / scribble / type on the watch; LLM and TTS settings sync from the iPhone via WatchConnectivity.
- **Mac Universal** – builds for both Apple Silicon (arm64) and Intel (x86_64).
- API keys are stored in the system **Keychain**.

## Requirements

| | Minimum |
|---|---|
| macOS | 14.0 |
| iOS | 17.0 |
| watchOS | 10.0 |
| Xcode | 16+ (developed with 26.2) |
| Tools | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |

## Build & Run

```bash
brew install xcodegen
xcodegen generate          # generates Twinkle.xcodeproj from project.yml
open Twinkle.xcodeproj
```

1. In Xcode, select your **Team** for the `TwinkleMac`, `TwinkleiOS` and `TwinkleWatch` targets.
2. Change the bundle ID prefix (`com.twinkle`) in `project.yml` to your own reverse-domain, then re-run `xcodegen generate`.
3. Run the `TwinkleMac` scheme, or run `TwinkleiOS` on an iPhone (it embeds the Watch app).
4. Open **Settings** in the app, enter your API key and choose a model.

Command-line Mac build:

```bash
xcodebuild -project Twinkle.xcodeproj -scheme TwinkleMac -configuration Release \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The result is a Universal binary (`x86_64 arm64`). iOS / watchOS builds require the matching platform components (Xcode ▸ Settings ▸ Components).

## Configuration

| Setting | Notes |
|---|---|
| Provider | Anthropic, or OpenAI-compatible |
| Base URL | Defaults: `https://api.anthropic.com` / `https://api.openai.com/v1` |
| API Key | Stored in Keychain |
| Model | Fetched from `GET /v1/models` (Anthropic) or `GET /models` (OpenAI-compatible); falls back to manual entry if unavailable |
| Read-aloud engine | System voices or OpenAI TTS (`/audio/speech`); a TTS key left empty reuses the OpenAI-compatible LLM key |

## Project structure

```
project.yml            XcodeGen spec (3 targets)
Shared/Core/           Shared by Mac, iOS and Watch
                       TranslationClient (streaming LLM), TranslatorViewModel,
                       AppSettings, TTSSettings, Speaker, Keychain, WatchSync,
                       Theme, EntryCard
Shared/Speech/         SpeechInput – real-time recognition (Mac + iOS)
Shared/UI/             TranslatorView, SettingsView (Mac + iOS)
Mac/  iOS/  Watch/     App entry points (Watch also has WatchView)
```

## Notes & limitations

- Voice input must pick its language before you speak, so in *Auto* mode the microphone assumes Chinese. Use **英→中** to speak English.
- The Watch has no direct speech-recognition API; it relies on the system dictation in the text field, and needs the paired iPhone (or Wi-Fi) for network access.
- Speech recognition uses Apple's Speech framework and may send audio to Apple, depending on the language and device.
- Development builds are ad-hoc signed on Mac; re-signing changes the identity, so the Keychain may ask for permission again. Use a stable developer signing identity to avoid this.
- Status: the Mac app builds and launches. The iOS and watchOS sources type-check, but the apps have not yet been run on a simulator or device, so voice input, Watch dictation and phone→watch sync are untested.

## License

No license has been chosen yet — add one before publishing.
