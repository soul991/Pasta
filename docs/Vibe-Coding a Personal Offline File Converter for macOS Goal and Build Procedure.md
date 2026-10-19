# Vibe-Coding a Personal Offline File Converter for macOS

*Goal and build procedure for an AI coding agent. Working name: Peel. Prepared October 18, 2026.*

## 1. How to use this document

- Sections 2 to 5 are the standing brief. Paste them to the AI once at the start of the project, and again whenever a session resets.
- Section 6 is the phase plan. Give the AI one phase at a time. Do not start the next phase until the gate passes and you have read the phase report.
- Section 7 is a command reference. Treat every command there as a starting point to be proven in Phase 1, not as guaranteed truth, because tool flags differ between versions.
- Section 8 is the test plan, Section 9 lists risks, and the appendices hold a ready-to-paste master prompt and a report template.
- The single most important rule: the AI must never claim something works unless it ran it and saw the output.

## 2. Goal

Build a personal, fully offline macOS app, inspired by the Tangerine file converter, that converts and processes files locally. The signature interaction: hold Shift while dragging a file, and a small panel appears with the formats you can convert it to. Hold Option as well and the panel shows advanced tools instead.

This is a personal tool for one Mac. It is not for sale or distribution. It must use its own name, icon and visual design, and must not copy Tangerine's branding or UI.

### Success criteria (v1)

1. Dragging a supported file with Shift held shows a panel of valid target formats. Clicking one produces the converted file next to the original within seconds, and the original is untouched.
2. With Option held, the panel offers advanced tools: compress, resize or crop, trim, remove metadata, merge or split PDFs.
3. A Finder right-click Quick Action offers the same conversions as a fallback.
4. A menu bar app with a drop window offers the same conversions without any keyboard trick.
5. The app never touches the network. It contains no networking code.
6. Every failure shows a clear human-readable message. Nothing fails silently.

### v1 scope

- Images: HEIC, JPG, PNG, WebP, TIFF, BMP, GIF, SVG (input only), AVIF where tooling allows.
- Video: MP4, MOV, MKV, WebM, GIF. Audio: MP3, M4A, FLAC, Opus, plus extracting audio from video.
- PDF: compress, merge, split, to images, to text.
- Documents: DOCX to TXT, Markdown or HTML.
- Subtitles: SRT and VTT.
- Archives: create ZIP and TAR.GZ, extract ZIP, TAR, RAR, 7z.
- Metadata removal for images and PDFs.

### Explicit non-goals for v1

- True PDF redaction (see the Deferred note in Section 6).
- PDF to DOCX conversion, and creating RAR files (RAR is proprietary, extraction only).
- App Store distribution, notarization, auto-update, cloud features, accounts.

## 3. Environment and constraints

- Target macOS 13 or later. Tangerine itself targets Apple silicon; do not assume this Mac is Apple silicon. The AI must run `uname -m` and `sw_vers` first. Homebrew lives in /opt/homebrew on arm64 and /usr/local on Intel.
- Language and UI: Swift 5.9 or later, SwiftUI for windows, AppKit for the drag overlay. Full Xcode must be installed; verify with `xcodebuild -version`.
- The app is not sandboxed, because it must read arbitrary files and launch external tools. Sign ad hoc for local use only.
- Engines are external command-line tools installed with Homebrew. The app discovers them and does not bundle them in v1.
- No third-party Swift packages unless the AI asks first and gives a reason.
- Suggested layout: `Peel/` (app target), `PeelCore/` (engine, no UI, unit tested), `PeelTests/`, `Fixtures/` (test files), `docs/commands.md`, `docs/PROGRESS.md`.

## 4. Architecture

One engine, several entry points. Every entry point (drop window, Shift-drag panel, Quick Action, CLI) calls the same engine, so a fix in one place fixes all of them.

- **ToolLocator**: finds binaries by absolute path, searching /opt/homebrew/bin, /usr/local/bin, /usr/bin and /bin. Returns a URL or a typed MissingTool error. This is required because GUI apps and Quick Actions do not inherit your shell PATH, a classic cause of it works in Terminal but not in the app.
- **FormatRegistry**: maps an input file type (by extension and UTType, case-insensitive) to the list of actions available for it.
- **ConversionAction**: id, display name, output extension, and a pure function `buildInvocations(input, output)` that returns the commands to run. Because it is pure, it can be unit tested without executing anything.
- **JobRunner**: runs invocations with Foundation `Process`. Async, with timeout, cancellation, captured stdout and stderr, and exit-code checking.
- **OutputPlanner**: chooses the output location, never overwrites, writes to a temporary directory first, then moves the result into place atomically.
- **UI layer**: MenuBarExtra, drop window, action panel, and later the DragMonitor.
- **CLI mode**: the same executable accepts `peel convert --action ACTION_ID FILE...` so Quick Actions and tests can call the engine headlessly.

## 5. Rules the AI must follow (anti-error contract)

1. **Verify before you write.** For every external tool, run `TOOL --version` and `TOOL --help` and confirm each flag exists before using it. Never invent flags, Swift APIs or AppKit APIs. If unsure whether an API exists on macOS 13, say so and check the SDK headers or documentation.
2. **Plan before code.** At the start of each phase, restate the goal and list the files you will create or change.
3. **Small steps.** One feature per change. Build after every step. Never end a step with a project that does not compile.
4. **Never run a shell string.** Use `Process` with `executableURL` and an `arguments` array. Never assemble commands by concatenating file paths into a string.
5. **Never overwrite or delete the user's original.** Write to a temp directory, then move atomically. On a name collision, add a numeric suffix.
6. **Check every exit code.** Capture stderr and show a readable error. No `try?` that swallows errors, no force unwraps, no `fatalError` on normal paths.
7. **Avoid pipe deadlocks.** Read stdout and stderr concurrently while the process runs, because a full pipe buffer hangs `Process`. Set standardInput to /dev/null. Add a timeout and cancellation, and terminate child processes on cancel.
8. **Treat every file name as hostile.** Spaces, quotes, unicode, emoji, leading dashes (pass `--` before paths where the tool supports it), very long names, no extension, uppercase extensions.
9. **No network code at all.** No URLSession, analytics or update checks.
10. **No placeholders presented as finished.** If something is deferred, say so in the report.
11. **No false claims.** Do not say a test passed unless you ran it. Paste the real output in the report.
12. **Stay in scope.** Do not refactor or rename anything outside the current phase.
13. **Stop and ask** when a requirement is ambiguous, a tool is missing, a gate fails twice, or you would need a package, entitlement or permission not listed here.
14. **Keep logic out of the UI.** Command building lives in PeelCore as pure, tested functions.
15. **Keep records.** Maintain `docs/commands.md` (proven working commands) and `docs/PROGRESS.md` (phase status and known issues).
16. **Commit at every green gate** with a clear message, so any phase can be rolled back.

## 6. Phase plan

Every phase after Phase 0 begins with **Step 0: re-verify the previous phase.** Re-run its gate checks, confirm it still builds and passes, and fix any fault found before adding anything new. Report what you found.

### Phase 0: Environment and tools

**Steps**

- Run `uname -m`, `sw_vers`, `xcodebuild -version`, `swift --version`, `brew --version`.
- Install the engines: `brew install ffmpeg imagemagick webp ghostscript qpdf poppler exiftool pandoc librsvg unar sevenzip`.
- Verify each tool with `--version` and print a table of tool, absolute path, version. Note anything missing or any formula name that failed.
- Create the repository (`git init`), the Xcode project, the folder layout from Section 3, and a Fixtures folder.
- Create fixtures: a small sample of each input type, plus the nasty file names listed in Section 8.

**Gate**: the tool table is printed with no unexplained gaps, fixtures exist, the empty project builds, first commit made.

### Phase 1: Prove every command by hand

**Steps**

- For each action in Section 7, run the command in Terminal on a fixture. Check the result is real: `file OUT`, `ffprobe OUT`, `qpdf --check OUT`, `identify OUT`, or open it.
- Record each exact working command in `docs/commands.md`, with the tool version.
- If a tool or flag does not work, fix it or mark the action unsupported. Do not carry unproven commands forward.
- Check which image formats ImageMagick really supports with `magick -list format`, and whether sips can write each target format.

**Gate**: every v1 action has a proven command and a verified output, or is listed as unsupported with the reason.

### Phase 2: Core engine (no UI)

**Steps**

- Implement ToolLocator, FormatRegistry, ConversionAction, JobRunner, OutputPlanner as described in Section 4, and the CLI mode.
- Unit tests: command builders produce the expected argument arrays for tricky names (spaces, quotes, leading dash, unicode); OutputPlanner collision handling; ToolLocator returns a clear error for a missing tool; case-insensitive extension matching.
- Integration tests run real conversions on tiny fixtures and check that outputs exist and originals are byte-identical (compare `shasum` before and after).

**Pitfalls**: pipe deadlock on large ffmpeg output, relative paths, tools writing to the current directory, forgetting `-n` or `-nostdin` for ffmpeg.

**Gate**: all tests pass, and `peel convert --action ACTION_ID FILE` works from Terminal for every v1 action.

### Phase 3: Menu bar app and drop window

**Steps**

- Menu bar only app (LSUIElement set to YES, no Dock icon) using MenuBarExtra.
- A window with a drop zone. Dropping one or more files shows the valid actions for their type. Clicking runs the job with a progress indicator, then a result row with Reveal in Finder, or an error row with the real message.
- Mixed file types in one drop must be handled sensibly (show only actions valid for all, or group by type).

**Gate**: manual checklist passes on fixtures, including a failure case (corrupt file) that shows a clear error.

### Phase 4: Advanced tools (the Option-key set)

**Steps**

- Compress image, video and PDF with a quality choice. Resize and crop images. Trim audio and video with validated start and end times. Remove metadata. Merge and split PDFs. Extract archives into a new folder.
- Validate inputs before running (end after start, numbers in range, at least two PDFs to merge).

**Gate**: every advanced action has an integration test and a manual check. Metadata removal is verified with `exiftool OUT` showing the fields gone.

### Phase 5: Finder Quick Action

**Steps**

- Create a Quick Action (Automator, receives files or folders in Finder, runs a shell script) that passes the selected files to the CLI mode using the absolute path of the app executable.
- Install into \~/Library/Services. Remember Quick Actions run with a minimal environment, so use absolute paths only and pass files as arguments, quoted correctly.

**Gate**: right-clicking files with spaces, quotes and unicode in their names converts them correctly.

### Phase 6: Shift-drag overlay (highest risk)

**6a. Spike first.** Build a tiny throwaway app that only logs events. Using a global `NSEvent` monitor for left-mouse-dragged events, check `NSEvent.modifierFlags` for Shift and Option, and read the drag pasteboard (`NSPasteboard(name: .drag)`) for file URLs. Confirm with real Finder drags what actually works on this Mac and macOS version. Report the evidence. Do not design from assumptions.

**6b. Implement.** On a qualifying drag, show a borderless floating non-activating `NSPanel` near the cursor, containing a drop target that registers for file URLs. Dropping on a format chip runs that action through the shared engine. The panel disappears when the drag ends or leaves. Option held changes the chips to advanced tools.

**6c. Permissions and fallback.** Find out empirically whether Input Monitoring or Accessibility permission is needed. If it is, show a clear first-run explanation and a link to the right System Settings pane. If the overlay proves unreliable, ship without it: the drop window and Quick Action already cover the need.

**Gate**: Shift-drag from Finder and from the Desktop works repeatedly, the panel never gets stuck on screen, normal drags without Shift are completely unaffected, and the app remains usable if permission is denied.

### Phase 7: Hardening and installation

**Steps**

- Launch at login with `SMAppService.mainApp.register()`. A preferences panel for output location (beside the original or a chosen folder).
- Log file in \~/Library/Logs/Peel. Clean up temp files on success, failure and cancel.
- Release build: `xcodebuild -scheme Peel -configuration Release build`. Ad hoc sign: `codesign --force --deep --sign - Peel.app`. Copy to /Applications.
- Run the full test plan in Section 8.

**Gate**: every Section 8 check passes on the installed Release build.

### Deferred: PDF redaction

Drawing black boxes on a PDF does not remove the text underneath, so it is not redaction. Do not ship a feature labelled redaction unless it truly removes content, for example by rasterizing the redacted pages and rebuilding the PDF, then verifying with `pdftotext` that the text is gone. Treat it as its own project after v1.

## 7. Command reference (starting points, to be proven in Phase 1)

Placeholders: IN is the input file, OUT the output file, DIR a directory. Always pass paths as separate arguments, never inside a shell string.

**Images**

- To JPG: `sips -s format jpeg IN --out OUT` (quality: add `-s formatOptions 80`). To PNG: `sips -s format png IN --out OUT`.
- To WebP: `cwebp -q 80 IN -o OUT`. cwebp reads only a few input formats, so convert HEIC to PNG first.
- AVIF and anything exotic: `magick IN OUT`, after checking `magick -list format`.
- SVG to PNG: `rsvg-convert -o OUT IN`.
- Resize: `sips -Z MAXPIXELS IN --out OUT`. Crop: `sips --cropToHeightWidth H W IN --out OUT`.

**Video and audio** (always include `-nostdin` and `-n` so ffmpeg never prompts or overwrites)

- Video to MP4: `ffmpeg -nostdin -n -i IN -c:v libx264 -crf 23 -preset medium -c:a aac -movflags +faststart OUT`.
- Video to WebM: `ffmpeg -nostdin -n -i IN -c:v libvpx-vp9 -crf 32 -b:v 0 -c:a libopus OUT`.
- Video to GIF: `ffmpeg -nostdin -n -i IN -vf 'fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' OUT`.
- Extract audio: MP3 `-vn -c:a libmp3lame -q:a 2`; M4A `-vn -c:a aac -b:a 192k`; FLAC `-vn -c:a flac`; Opus `-vn -c:a libopus -b:a 128k`.
- Trim (accurate): `ffmpeg -nostdin -n -i IN -ss START -to END -c:v libx264 -c:a aac OUT`. Fast but not frame-accurate: put `-ss START -to END` before `-i` and use `-c copy`.
- Compress video: the MP4 command with a higher CRF such as 28.
- Subtitles: `ffmpeg -nostdin -n -i IN.srt OUT.vtt` and the reverse.

**PDF**

- Compress: `gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=OUT IN` (/screen is smaller, /printer is larger).
- To images: `pdftoppm -png -r 150 IN OUTPREFIX`, which writes one file per page, so output into a new folder.
- To text: `pdftotext -layout IN OUT`.
- Merge: `qpdf --empty --pages A B -- OUT`. Split: `qpdf IN --split-pages OUT`, which writes numbered files.
- Images to PDF: ImageMagick may block PDF output through its policy file. If so, use PDFKit from Swift instead.

**Documents**

- DOCX to TXT, Markdown or HTML: `pandoc IN -o OUT`.
- DOCX to PDF needs LibreOffice (`soffice --headless --convert-to pdf --outdir DIR IN`), a large optional install. PDF to DOCX is out of scope.

**Metadata**

- Images: `exiftool -all= -o OUT IN`.
- PDFs: copy the file, run `exiftool -all= -overwrite_original` on the copy, then rewrite it with `qpdf COPY OUT`. exiftool alone only appends an update, so the old metadata can stay recoverable. Verify with `exiftool OUT` that the fields are gone.

**Archives** (always extract into a new folder)

- ZIP: `ditto -c -k --sequesterRsrc --keepParent IN OUT.zip`. Unzip: `ditto -x -k IN DIR`.
- TAR.GZ: `tar -czf OUT -C PARENTDIR NAME`. Extract: `tar -xf IN -C DIR`.
- RAR (extract only): `unar -o DIR IN`. 7z: `7zz x IN -oDIR`.

## 8. Test plan

**Nasty file names** (create each in Fixtures): spaces in the name, a name with an apostrophe, unicode (Japanese or Bengali), an emoji, a leading dash (`-weird.mp4`), no extension, an UPPERCASE.JPG extension, a very long name, a 0-byte file, a corrupt file with a valid extension.

**Situations**: a name collision with an existing output, two or more files at once, a read-only destination folder, a file on an external drive, a 1 GB or larger video, cancelling mid-conversion, a missing tool (temporarily rename one).

**Checks for every action**

1. The output exists and opens correctly.
2. The original is untouched: `shasum` is identical before and after.
3. Errors are shown clearly for the corrupt and missing-tool cases.
4. No leftover temp files, and no orphan processes after cancel (`pgrep ffmpeg` returns nothing).
5. No network use during a run (watch with `nettop` or `lsof -i`).
6. Normal drags and drops across macOS are unaffected when the app is running.

## 9. Risks and honest limits

- **The Shift-drag overlay is the riskiest part.** macOS has no simple public API for system-wide drag detection, and behaviour may differ between macOS versions. This is why Phase 6 starts with a spike and why the app delivers value without it.
- **Homebrew tools update independently.** A `brew upgrade` can change flags or behaviour. Re-run the Phase 1 and Phase 2 tests after upgrading.
- **Quality depends on the underlying tools**, not on any special engine, so results and speed will match those tools.
- **Licensing:** ffmpeg builds can carry GPL terms. This does not matter for private use, but matters if you ever distribute the app.
- **Not notarized or sandboxed:** fine for your own Mac, not for sharing.

## Appendix A: Master prompt (paste at the start)

You are building a personal, offline macOS file converter app (working name Peel) in Swift and SwiftUI. Read the whole brief below before writing any code. Follow the rules in Section 5 exactly. Work in the phases of Section 6, one phase at a time, and stop at the end of each phase to give me a report in the Appendix B format. Do not start the next phase until I say so. Begin with Step 0 of the phase to re-verify the previous phase. Never claim anything works unless you ran it and can show the output. If anything is ambiguous, ask me instead of guessing. Start with Phase 0 now.

## Appendix B: Phase report template

The AI must end every phase with this report:

- **Phase and goal** restated in one line.
- **Step 0 re-verification**: what was re-checked from the previous phase, and any faults found and fixed.
- **What I did**, and the files created or changed.
- **Commands run and real output**, trimmed but not invented.
- **Gate checklist**: each gate item marked pass or fail, with evidence.
- **Known issues and deferred items.**
- **Questions for me.**
- **Ready for the next phase?** Yes or no, and why.

To start the next phase, send: Proceed to Phase N. Begin with Step 0, re-verify Phase N-1, fix any faults, then continue under the same rules.
