<div align="center">

# 🎙️ Murmur

**Live transcription that never leaves your phone.**

Speak, and watch your words appear in real time, transcribed entirely on-device by a
17 MB speech model. No internet permission, no account, no cloud.

[**Download the APK**](https://github.com/MohamedFarhan23/murmur/releases) · Android 7.0+ · English

</div>

---

## Why Murmur

### 🔒 Local-only, by design
Your voice is processed on your phone's CPU and nowhere else. Murmur doesn't just
promise this: the app **does not request the Internet permission**, so Android itself
guarantees it cannot send anything off the device. Check it under *App info →
Permissions*: the microphone is the only thing it asks for.

### 🪶 Remarkably light
| | |
|---|---|
| Speech model | **17 MB** ([Whistle](https://huggingface.co/Cactus-Compute/whistle), 2–4-bit) |
| Model load | **~0.26 s** |
| 15 s of audio, transcribed in one pass | **~0.28 s** |
| Live streaming pass (per second of audio) | **35–210 ms** |
| GPU / NPU needed | **No**: plain CPU |

<sub>Measured on a Pixel 7a.</sub>

### ⚡ Rich, but out of your way
- **Live, word-by-word transcription.** Confirmed words appear solid; the words still
  being decided show dimmed, then settle.
- **Silence stays silent.** A voice activity detector sends only speech to the model,
  so pauses don't turn into invented text and the battery isn't spent on silence.
- **Knows when it's unsure.** Low-confidence words get a subtle dotted underline.
- **Tap any word to fix it.** Get *sounds-like* suggestions ("Disting." → *testing*),
  type a correction, or remove it, with Undo.
- **Teach it your words.** Tick *Remember this word* and Murmur biases recognition toward
  your names, places and jargon from then on. Manage them on the *Custom words* page.
- **Feels physical.** Haptics on start/stop, a soft tick each time a phrase is
  finalized, and a voice-reactive ring around the mic button.
- **Pause and continue** the same transcript; **Copy** it in one tap; **Clear** with
  Undo.
- **Respects your settings**: light and dark themes, and *Remove animations*.

---

## Install

1. Download `murmur-v*-arm64.apk` from the
   [releases page](https://github.com/MohamedFarhan23/murmur/releases).
2. Open it on your phone and allow installing from your browser or file manager when asked.
3. Tap the mic. Android asks for microphone access once.

Requires a 64-bit ARM phone (practically every Android phone from the last several
years) running Android 7.0 or newer.

## Good to know

- **English only** for now. Whistle also knows German, French, Spanish, Italian, Dutch
  and Polish, which may come later.
- Built for **natural sentences**. A single word said on its own is the hardest case for
  any small model; that's what tap-to-fix and *Remember this word* are for.
- Any voice sound is transcribed as the closest word, so mumbling may show up as a short
  word like "Yeah.". It will usually be underlined as unsure.

---

## How it works

```
Mic (16 kHz) ─▶ VAD (WebRTC) ─▶ Whistle streaming ─▶ words + confidence ─▶ UI
                   │                  │
       drops silence, ends      commits words once two
       a phrase on each pause   consecutive passes agree
```

- **Flutter** UI, with the engine called over `dart:ffi`.
- **[Needle](https://huggingface.co/Cactus-Compute/needle3)**, Cactus Compute's C++
  inference engine, runs Whistle on a dedicated isolate so the UI never waits on it.
- **[libfvad](https://github.com/dpirch/libfvad)** (WebRTC VAD) gates the microphone in
  30 ms frames; each pause ends the stream, which keeps every pass short and fast.
- **Sounds-like suggestions** compare pronunciation keys with a sound-aware edit distance
  over 44k common English words ([SCOWL](http://wordlist.aspell.net)), on their own isolate.

## Build from source

```sh
git clone git@github.com:MohamedFarhan23/murmur.git && cd murmur/app
./tool/fetch_model.sh          # downloads whistle.cact (pinned, checksum-verified)
flutter build apk --release --target-platform android-arm64
```

Needs the Flutter SDK (stable), the Android SDK with **NDK 28.2** and **CMake 3.22.1**,
and JDK 17 or 21. The Needle engine binaries and libfvad sources are vendored in
`third_party/`. Add `--dart-define=MURMUR_DEBUG=true` to log every phrase and engine
result to logcat.

## Credits

| Component | By | License |
|---|---|---|
| [Whistle](https://huggingface.co/Cactus-Compute/whistle) speech model | Cactus Compute | Apache-2.0 |
| [Needle](https://huggingface.co/Cactus-Compute/needle3) inference engine | Cactus Compute | Apache-2.0 |
| [libfvad](https://github.com/dpirch/libfvad) voice activity detection | WebRTC authors, Daniel Pirch | BSD-3-Clause |
| [SCOWL](http://wordlist.aspell.net) word list | Kevin Atkinson and contributors | [SCOWL license](app/assets/words/SCOWL-LICENSE.txt) |
| [Flutter](https://flutter.dev), [record](https://pub.dev/packages/record) | Google, llfbandit | BSD-3-Clause |
