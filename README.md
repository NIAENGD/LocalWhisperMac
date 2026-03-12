# LocalWhisperMac

A modern **macOS (Apple Silicon only)** GUI app that transcribes local audio/video files with `whisper.cpp`.

## What is included
- App icon is sourced from the repository `icon.png` during packaging.
- One-screen SwiftUI desktop app.
- First-run setup wizard that imports a model you download from Hugging Face:
  - User-provided model (`ggml-medium.en.bin` for English or `ggml-medium.bin` for multilingual).
- Offline transcription workflow with:
  - file picker,
  - start button,
  - live progress bar,
  - transcript area,
  - copy button,
  - save-as-TXT button.
- Chinese/English localization based on system language (`zh*` => Chinese, all others => English).

## Build (one click)
```bash
./Scripts/build_app.sh
```

After build, the app bundle will be generated at:

```text
dist/LocalWhisperMac.app
```

Drag it to `/Applications` if desired.

## Runtime behavior
- Requires `whisper-cli` to be available at one of:
  - `~/Library/Application Support/LocalWhisperMac/bin/whisper-cli`
  - `/opt/homebrew/bin/whisper-cli`
  - `/usr/local/bin/whisper-cli`

- First launch shows setup card.
- User chooses model type (English or multilingual).
- App stores runtime assets into:
  - `~/Library/Application Support/LocalWhisperMac/bin`
  - `~/Library/Application Support/LocalWhisperMac/models`
- Click **Open on Hugging Face** and manually download one of:
  - `ggml-medium.en.bin` (English)
  - `ggml-medium.bin` (multilingual)
  Then click **Import Downloaded Model**; the app copies the model into its own Application Support folder so the original file can be deleted.
- Future runs are fully local/offline.

## Notes
- Requires macOS 13+.
- The packaged app is configured for Apple Silicon (`arm64`) only.
