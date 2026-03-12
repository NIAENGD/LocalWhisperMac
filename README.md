# LocalWhisperMac

A modern **macOS (Apple Silicon only)** GUI app that transcribes local audio/video files with `whisper.cpp`.

## What is included
- App icon is fetched during packaging from the official `whisper.cpp` Android launcher icon URL.
- One-screen SwiftUI desktop app.
- First-run setup wizard that downloads:
  - `whisper-cli` prebuilt binary (Apple Silicon).
  - Default model (`ggml-medium.en.bin` for non-Chinese systems, multilingual medium for Chinese systems).
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
- First launch shows setup card.
- User chooses model type (English or multilingual).
- App downloads runtime assets once into:
  - `~/Library/Application Support/LocalWhisperMac/bin`
  - `~/Library/Application Support/LocalWhisperMac/models`
- If model auto-download fails on your network, click **Open on Hugging Face** and manually download one of:
  - `ggml-medium.en.bin` (English)
  - `ggml-medium.bin` (multilingual)
  Then click **Import Downloaded Model**; the app copies the model into its own Application Support folder so the original file can be deleted.
- Future runs are fully local/offline.

## Notes
- Requires macOS 13+.
- The packaged app is configured for Apple Silicon (`arm64`) only.
