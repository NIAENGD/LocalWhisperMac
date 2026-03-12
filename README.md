# LocalWhisperMac

A modern **macOS (Apple Silicon only)** GUI app that transcribes local audio/video files with `whisper.cpp`.

## What is included
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
- Future runs are fully local/offline.

## Notes
- Requires macOS 13+.
- The packaged app is configured for Apple Silicon (`arm64`) only.
