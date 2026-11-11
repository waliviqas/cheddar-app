# Cheddar — context for the next chat (written 2026-11-10, night before the demo)

Paste this whole file into the new chat. It's everything the last chat knew.

## 1. Who / what / when

- **Wali** is building **Cheddar**, an iOS hockey shot-speed app: a phone on a tripod films the shot in 240 fps slow-mo and reads the puck's speed (a "portable radar gun") plus which square of the net it went in.
- **Demo tomorrow (2026-11-11) with Kyle Okposo.** Wali said accuracy won't be checked at the demo; what matters is a working, clear UI.
- **What Wali wants for the demo:** the **live camera running** while shooting, and each shot's **speed popping up on screen every time a shot happens** ("live shots"). He wants to run it from **Xcode himself**, not inside Claude.

## 2. How Wali wants Claude to work (follow exactly)

- Talk like a person: short, plain, no over-explaining, flowy sentences, not chunky bullet dumps. Define things simply. He gets confused by long answers and says so.
- One step at a time; say what you'll do, do it, report. Tests first, then implement ("write the tests, then implement against them").
- Before implementing, he often asks "which classes does each test call" — answer with a plain list.
- **Never commit or push without asking every time.** Show the short commit message first. **Never add a Claude co-author trailer.**
- Push personal repo with: `git push git@github-personal:waliviqas/cheddar-app.git main:main`
- **Never paste secrets in chat.** Secrets live in `~/.cheddar-secrets/` (`openai-key`, `replicate-token`, `hf-token`, `gemini-key`), saved with `read -s`. Never print them.
- Don't change his code when he says "don't change code" — use throwaway tests (copy a file into `backend/Tests/CVPipelineTests/`, run, delete) or a scratch package.
- Wiki: update `/Users/waliviqas/Documents/Wali's Neural Network/wiki/Cheddar.md` as decisions happen; end the session with a line in `.../log.md`.

## 3. Repo layout

`~/personal-projects/cheddar-app/` (GitHub `waliviqas/cheddar-app`, branch `main`)
- `backend/` — Swift package **CVPipeline** (iOS 17 / macOS 14). All the CV code + tests.
- `ui/Cheddar.xcodeproj` — the iOS app (SwiftUI, iOS 17, bundle id `com.viqas.Cheddar`, scheme `Cheddar`). Already links `../backend` as a local package (`import CVPipeline`).
- `backend/videos/` is gitignored (clips, masks, click JSONs, frames).
- `Application Flow V1.pdf` — hand-drawn flow: capture/upload → calibrate → CV → show mph per shot with a clip → (later) Supabase sync, Claude coaching, leaderboards.

## 4. The pipeline (backend/Sources/CVPipeline)

Order for one video:
1. **ClackFinder** — hears the stick-on-puck "clack" in the audio (fed 20 ms packs, 960 samples @ 48 kHz, `add(_:startSeconds:)` → clack times). Rule: 16× the median loudness of the last 1 s.
2. **Net setup** — user taps the 4 **inside** net corners (always inside edge). `NetCornerFinder().find(in:taps:mask:)` snaps taps onto a SAM 3 outline (`FrameMask`, from `ReplicateFrameMasker` on Replicate). `CameraPose(corners:lens:)` → where the phone is and how it's tilted. Net opening = 72 × 48 in. `LensInfo(width:height:centerX:centerY:zoom:)`; for Wali's iPhone 14 Plus 1x at 1920 wide, best zoom ≈ **1475** px (the guess was 1387).
3. **VideoFrameExtractor().frames(from:between:and:)** → `[(image: CGImage, seconds: Double)]` (real timestamps; slow-mo skips ~1 frame in 10, avg ~207 fps).
4. **PuckDetector** — Wali's trained Core ML puck model (`PuckModel.mlmodel`). `pucks(in:)` scans the whole frame (y from bottom, slow ~0.25 s/frame). **New:** `pucks(in:near:)` scans only the 320 px square around a spot (y down, fast).
5. **PuckLinker** — `path(from:times:lookingNear:)` follows the shot puck frame by frame, asking PuckDetector only near where the puck should be next (cached squares, ignores still look-alikes, handles takeoff and speeding up off the blade). Returns `[CGPoint?]` (y down).
6. **ReleaseFinder** — finds the frame the puck leaves the blade. Cuts a 260×180 close-up centered on the puck in each frame and asks **OpenAI `gpt-6.1-terra` with reasoning `none`** "TOUCHING or LEFT?" (prompt describes only the puck and stick — no colors/rink, must work for any user; no "if unsure say TOUCHING" line). Window: 10 frames before the **moving point** (first frame puck > 4 px from its clack spot; never before the clack) to 25 after, **all sent at once**. Release = earliest LEFT that the next frame also says LEFT **and that comes after at least one TOUCHING** (fix 1, added today). Key from `~/.cheddar-secrets/openai-key` in tests. Real shot ≈ 2–4 s per shot, ~1¢.
7. **ShotFlight** — `init?(path:times:releaseTime:pose:lens:)`. Release spot on the ice via **FloorSpot**, fits start + v·t + ½·pull·t² (gravity on z). Gives `releaseMph` (from the **20 frames after the release** — the number the app should show), `crossingTime`, `crossingSpot` (inches across/up), `distance`, `flightTime`.
8. **NetGrid** — `square(across:up:)` → `NetSquare` (3×3: topLeft…bottomRight, `.post`, `.missed`).
9. **ClackShotReader** (new, uncommitted) — `ClackShotReader(pose:lens:openAIKey:).shots(in: videoURL) async throws -> [Shot]`; `Shot { clackTime, startSpot, mph: Double?, square: NetSquare? }`. Reads audio → clacks (minus 0.0175 s sound delay) → for each clack: 0.45 s of frames → every puck in frame 0 → follows each → picks the one that travels farthest (first move ≤ 60 px, ≥ 150 px total) → ReleaseFinder (first 40 frames) → ShotFlight → speed + square. Skips clacks within 0.45 s of the last shot.

Older pieces from a previous design (RinkShotReader, ShotAnalyzer, PuckTracker, FlightLine, SpeedCalculator, PuckRuler, PuckShapeFinder) are not used by the new chain; their tests make the full suite take 20+ min. Run targeted suites instead.

## 5. Git state

Committed and pushed today:
- `6045298` Find the release with OpenAI and only search near the puck
- `766ddc2` ShotFlight starts the clock at the release

**Uncommitted (ask before committing):**
- `backend/Sources/CVPipeline/ShotFlight.swift` + tests — `releaseMph` from 20 frames after release; shared `fit` helper; real-shot test now checks release speed within 5 mph of **48.6** (puck-size speed), not the radar.
- `backend/Sources/CVPipeline/ClackShotReader.swift` + `Tests/CVPipelineTests/ClackShotReaderTests.swift` (3 tests).
- `backend/Sources/CVPipeline/ReleaseFinder.swift` + tests — fix 1 (LEFT only counts after a TOUCHING) + test "ignores LEFTs before the blade reaches the puck".
- Old leftovers from Oct 25 (not part of this work; don't commit without asking): PuckRuler.swift/Tests, RinkShotReader.swift, FlightLine.swift/Tests, backend/README.md.
- Proposed commit message: "ClackShotReader reads every shot in a video — Hears the clacks, picks the puck that flies, finds the release with OpenAI, and reads the speed off the stick and the grid square. ReleaseFinder only counts a LEFT after seeing the puck touch the blade. ShotFlight reads the release speed from the 20 frames after the release."

## 6. Test status (last run)

- ReleaseFinder: 8/8 pass (incl. real shot with OpenAI).
- ShotFlight: 10/10 pass.
- PuckLinker, PuckDetector: pass.
- ClackShotReader: 2/3 pass. **"picks the puck that's shot" fails** on 43mph-54mph shot 2: the read starts from an early sound (13.932 s vs real hit 13.964), so the start spot is the puck mid-drag (196, 914) instead of (237, 905). Speed is fine. Fix 2 solves it.

## 7. Known issues / planned fixes (deferred until after the demo)

- **Fix 2 — one clack per burst, at the loudest moment.** One shot makes a burst of detections (e.g. 13.932…14.028). Picking the loudest 4 ms stretch (after ClackFinder's 2 kHz low cut) lands within 2 ms of the real hit on all 10 shots; first detection only 4/10. Belongs in ClackFinder (it has the filtered loudness); adds ~0.1 s latency. Tests: new fake-sound "uses the loudest sound in a burst"; change "finds every shot in the rink clips" to exactly one clack per shot within 5 ms.
- **Fix 3 — drop non-shots.** A full run read 26 non-shot sounds as shots (25 with no speed, one at **1,638 mph**). Only report shots with a real speed, reject > 130 mph. Test: whole 47mph-52mph clip → exactly 2 shots with sensible speeds.
- ShotFlight throws away a good release speed if only the crossing fails (crossing guard `time - lastSeen <= 4/240`). Could make the crossing optional.
- 43mph-49mph shot 2: PuckLinker loses the puck.
- NetCornerFinder snapping varies per clip (43mph-49mph camera is off: height 51.8 vs tape 61.5); raw taps might be more stable.
- ClackShotReader is slow on whole clips (53–116 s) because it reads every sound and follows every puck in frame 0.

## 8. Accuracy findings (so nobody re-investigates)

- Wali's tape (Nov 4, 1x): net inside 72×48, ice→lens 61.5, tripod→goal line 233, tripod→shooting spot 236, shooting spot→goal line 192. Tape is only for checking; users never measure anything.
- Cheddar's camera math vs tape on clips with their own clicks: within a few %.
- Speed from the puck's own 3-inch width (~7 px/in on the flying puck, no camera math) agrees with the camera math; 8× zoom changed nothing.
- Gravity check: the flight's bend has median ~28 ft/s² vs 32.2 → the video clock is fine.
- Conclusion: Cheddar reads ~5–15% above the radar, but distance and clock both check out; the radar (behind the net, not always shot straight at) likely reads low. Wali agrees his numbers are more trustworthy.
- Latest per-shot reads (camera math release speed / puck-size speed / radar): 43-54 #1 51.2/48.6/43; #2 57.2/54.2/54; 54-52 #1 54.9/56.2/54; #2 55.4/56.3/52; 58-49 #1 63.6/59.6/58; #2 60.2/55.0/49; 43-49 #1 48.8/57.5/43; 47-52 #1 62.5/60.9/47; #2 58.4/58.3/52.
- Model shootout for the release: Gemma 4 31B failed (blue tape, flip-flopping); gpt-6-astra great but slow/expensive; gpt-6-luna calls LEFT too early; **gpt-6.1-terra chosen**.

## 9. Data (all under backend/videos/rink-clips/, gitignored)

- `1x-measured/{43mph-54mph,54mph-52mph,58mph-49mph,43mph-49mph,47mph-52mph}.MOV` + `measurements.json` (radar mph per shot).
- Shot clack times (heard): 43-54: 8.401, 13.964; 54-52: 9.510, 16.645; 58-49: 9.452, 14.319; 43-49: 8.498, 13.291; 47-52: 8.223, 12.556. Release frames (1 = clack frame): 13, 12, 14, 9, 12, 14, 15, 7, 12, 12.
- `net-outline.json` — Wali's inside-corner clicks for all 5 measured clips. `shot-spots.json` — tape + puck-at-clack clicks for all 5. `sam3-masks/measured-*.png`, `net-frames/measured-*.jpg`, `clack-frames/*.jpg`.
- Click pages: `net-inside-corners*.html`, `shot-spot-marker*.html`, `crossing-check.html` (+ `crossing-check/`).
- Camera setup used everywhere: `placeCamera` in `backend/Tests/CVPipelineTests/ClackShotReaderTests.swift`.

## 10. The iOS app today (ui/Cheddar, 8 files, all SwiftUI)

- `CheddarApp` → `LandingView` ("🧀 Cheddar — Your portable hockey radar gun", Get Started) → `RecordView` (full-screen `CameraPreview`, red record button / stop button, "Clocking your shot…" spinner, `ResultView` overlay with one mph + "Another Shot").
- `ShotRecorder` — back wide camera at 240 fps via `AVCaptureMovieFileOutput`, temp `.mov`. **Video only — no microphone input**, so ClackFinder would hear nothing.
- `RecordViewModel` — phases idle/recording/analyzing/result.
- `ShotSpeedReader` — **old** code: `ShotAnalyzer` with a placeholder 100 px/ft. Not ClackShotReader.
- Info.plist via build settings: camera string says "Video never leaves your phone" (false now — frames go to OpenAI). **No microphone or photo-library strings.**
- No server/endpoints exist or are needed: the app calls CVPipeline directly; the only outside call is OpenAI (and Replicate if SAM 3 is used).

## 11. What to build next (the UI for the demo)

Wali chose **live shots**: camera running, speed pops up on screen each time a shot happens.

Needed:
1. **Microphone** in the capture session + `INFOPLIST_KEY_NSMicrophoneUsageDescription`; fix the camera usage string.
2. **Net setup screen** before shooting: freeze a camera frame, user taps the 4 inside corners → `CameraPose(corners:lens:)`. For the demo, use the raw taps (skip SAM 3 / Replicate / NetCornerFinder).
3. **LensInfo from the device**: width/height of the capture format, center = half, zoom = (width/2) / tan(videoFieldOfView/2) (FOV from `activeFormat.videoFieldOfView`, degrees).
4. **OpenAI key in the app (demo only):** a gitignored `Secrets.swift` or xcconfig generated from `~/.cheddar-secrets/openai-key` (never print it). Long term the app must call OpenAI through our own server.
5. **Live detection:** run ClackFinder on live mic packs (`AVCaptureAudioDataOutput`, convert to 48 kHz mono Float, 960-sample packs). On a clack, wait ~0.5 s, then read that shot. ClackShotReader's per-clack `read(_:at:)` is private and works on a file — expose a per-clack API. Getting the frames is the hard part: keeping 240 fps × 1 s of full frames in memory is ~1–2 GB. Options: record continuously with `AVAssetWriter` in rolling ~2 s segments and read the segment(s) covering the clack; or keep a ring buffer of downscaled/cropped frames. Simplest reliable fallback for the demo: record → stop → read the clip with ClackShotReader → play it back with each shot's mph popping up at its clack time (AVPlayer + overlay).
6. **Shot display:** big mph number on screen for a few seconds per shot, plus the net square (simple 3×3 grid with the square lit), and a running list of shots.
7. The simulator has no camera: test live mode on Wali's iPhone (Xcode: plug in, pick the phone, set Signing Team, ⌘R). For simulator testing, add a "pick a video" path (PhotosPicker; add clips with `xcrun simctl addmedia <udid> <file>`).

Simulator booted: iPhone 18 Pro (BF55EDBC-6C6A-4473-8B69-ADCFBD93DA6A). Open the project: `open ~/personal-projects/cheddar-app/ui/Cheddar.xcodeproj`.
