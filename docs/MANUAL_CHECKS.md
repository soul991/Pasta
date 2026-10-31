# Pasta: Real Mac Manual Verification Checklist

*This document details all hardware, AppKit UI, OS permission, and interaction tests that cannot be fully verified in headless CI and require manual verification on a real Mac running macOS 13+.*

---

## 1. Accessibility Permission Flow (`AXIsProcessTrusted`)

CI runners operate in headless non-interactive environments where Accessibility API trust prompts cannot be displayed or confirmed.

- [ ] **First Launch Prompt**:
  - Launch `Pasta.app` on a fresh macOS account or after removing Pasta from **System Settings > Privacy & Security > Accessibility**.
  - **Expected:** Pasta displays an alert explaining why Accessibility access is needed (to detect the global Shift key hold during a drag session outside the window) and offers a button to open **System Settings**.
- [ ] **Permission Grant & Live Polling**:
  - In System Settings, toggle Pasta to ON.
  - Return to Finder.
  - **Expected:** Pasta detects permission without requiring an app relaunch.

---

## 2. Real Finder Drag Session & Pasteboard Detection

CI cannot simulate a real interactive drag session initiated from Finder or another application with mouse movement across displays.

- [ ] **No Drag Session (Negative Test)**:
  - Without dragging any file, press and hold <kbd>Shift</kbd> anywhere on the desktop.
  - **Expected:** Absolutely nothing happens. No ring, no wheel, no cursor change.
- [ ] **Text / Non-File Drag (Negative Test)**:
  - Highlight text in TextEdit or Safari, begin dragging the text snippet, and hold <kbd>Shift</kbd>.
  - **Expected:** Nothing happens. The pasteboard contains `public.utf8-plain-text`, not file URLs (`public.file-url`).
- [ ] **Single File Drag**:
  - Drag a `.png` file from Finder. While holding the mouse button down, hold <kbd>Shift</kbd>.
  - **Expected:** Drag session is recognized, armed, and triggers the charging sequence.
- [ ] **Multi-File Drag (Batch)**:
  - Select 3 image files in Finder, drag them, and hold <kbd>Shift</kbd>.
  - **Expected:** Wheel opens showing batch-compatible actions (e.g., collage, images to PDF, batch convert).

---

## 3. Shift-Hold Timing & Charging Progress Ring

CI tests verify the mathematical state machine against simulated clock timestamps (`DragMonitorClock`). A real human finger on a physical keyboard must verify the tactile timing feel.

- [ ] **Graze / Short Tap (< 120 ms)**:
  - While dragging a file, graze or tap <kbd>Shift</kbd> quickly (< 120 ms).
  - **Expected:** No visual feedback whatsoever. No flicker, no ring, no wheel.
- [ ] **Sub-Threshold Hold (449 ms)**:
  - Hold <kbd>Shift</kbd> for ~300 ms (between 120 ms and 449 ms).
  - **Expected:** A thin circular progress ring appears around the cursor after 120 ms and starts filling. Upon releasing before 450 ms, the ring disappears immediately. No wheel opens.
- [ ] **Deliberate Hold (450 ms)**:
  - Hold <kbd>Shift</kbd> steadily past 450 ms.
  - **Expected:** The progress ring reaches 100% exactly at 450 ms, disappears, and the circular radial options wheel blooms outward from the cursor with a spring animation.
- [ ] **Interrupt / Other Key Cancel**:
  - While the progress ring is filling (e.g. at 250 ms), tap any other key (e.g. Space, Command, or a letter key).
  - **Expected:** Charging aborts immediately. The ring vanishes and state returns to Idle.

---

## 4. Latching & Dismissal Behavior

- [ ] **Latching Open on Shift Release**:
  - Once the wheel blooms at 450 ms, release the physical <kbd>Shift</kbd> key while keeping the mouse button pressed (dragging).
  - **Expected:** The wheel **latches** and remains open. It does not vanish when Shift is released.
- [ ] **Escape Key Dismissal**:
  - While the wheel is open, press <kbd>Esc</kbd>.
  - **Expected:** The wheel closes immediately. The file drag continues uninterrupted.
- [ ] **Drop on Slice (Action Execution)**:
  - Release the mouse button over a format slice (e.g. "PNG" or "JPG").
  - **Expected:** The slice shows the active dark ink hover state, the wheel dismisses, conversion starts, and the converted file appears next to the original in Finder with an animated HUD notification.
- [ ] **Drop Outside (Natural Drop)**:
  - Drag the mouse away from the radial wheel onto a Finder folder or desktop and release.
  - **Expected:** The wheel dismisses, and the normal Finder drop occurs without running a Pasta conversion.
- [ ] **Second Shift-Hold Dismissal**:
  - While the wheel is latched open, hold <kbd>Shift</kbd> again for 450 ms.
  - **Expected:** The wheel closes cleanly.

---

## 5. Mode Toggling: Convert vs. Advanced Mode (<kbd>⌥</kbd>)

- [ ] **Quick Option Tap (< 250 ms)**:
  - While the wheel is open, quickly tap the <kbd>Option</kbd> (<kbd>⌥</kbd>) key.
  - **Expected:** Wheel slices smoothly transition between **Convert** mode (target file formats: JPG, PNG, WebP, etc.) and **Advanced** mode (Compress, Resize, Trim, Split, Metadata Strip).
- [ ] **Second Quick Option Tap**:
  - Tap <kbd>Option</kbd> again.
  - **Expected:** Wheel returns to **Convert** mode.
- [ ] **Option Hold (> 250 ms) (Negative Test)**:
  - Press and hold <kbd>Option</kbd> for 1 second.
  - **Expected:** Wheel does NOT toggle mode on a long hold (prevents accidental toggling when using Option for Finder drag-copy).

---

## 6. Menu Bar Glyph & System Tinting

- [ ] **Light Mode Appearance**:
  - Set macOS to Light Appearance.
  - **Expected:** The menu bar bowtie glyph (`MenuBarIcon.pdf`) renders in dark graphite/black, matching standard macOS menu bar items.
- [ ] **Dark Mode Appearance**:
  - Set macOS to Dark Appearance.
  - **Expected:** The menu bar bowtie glyph renders in crisp white/light gray with automatic template tinting (`NSImage.isTemplate = true`).
- [ ] **Accent Color Tinting**:
  - If a custom menu bar highlight is applied, verify template tinting respects system accent highlights without artifacting.

---

## 7. App Icon & Dock Resolution Check

Inspect `Pasta.app` on the macOS Dock, Launchpad, and Finder at standard resolutions:

- [ ] **1024 x 1024 / 512 x 512 (Retina Display Master)**:
  - Squircle shape, obsidian gradient background (`#2B2233` to `#120D18`), subtle 8-segment radial ring ticks, farfalle bowtie wings in sunset gradient (`#FFB347` to `#F2611F`), crimped scalloped wing edges, center pinch band, and contact shadow.
- [ ] **128 x 128 / 64 x 64 (Finder Icon View)**:
  - Bowtie shape remains immediately legible; sunset gradient preserves contrast against dark squircle.
- [ ] **32 x 32 / 16 x 16 (Finder List View & Dock Mini)**:
  - Evaluated out of 10:
    - Shape legibility: > 8/10 (distinct bowtie silhouette)
    - Depth & contrast: > 8/10 (bright pinch against obsidian backdrop)
    - No muddy artifacts or unrecognizable blur.

---

## 8. Visual Materials & Motion Settings

- [ ] **macOS Material Translucency**:
  - Open the wheel over various desktop backgrounds (light wallpaper, dark wallpaper, complex photo).
  - **Expected:** `NSVisualEffectView` HUD window material renders with native vibrancy, blur, and subtle border rim highlight.
- [ ] **Reduce Motion (System Accessibility)**:
  - Enable **System Settings > Accessibility > Display > Reduce motion**.
  - Trigger the wheel.
  - **Expected:** The charging ring animation is bypassed; the wheel appears at 450 ms with an instant alpha crossfade instead of the blooming spring scale animation.
- [ ] **Active Slice Contrast**:
  - Hover over a sunset-filled active slice.
  - **Expected:** Active text label uses dark ink `#1A0F05`, ensuring > 8:1 contrast ratio against bright orange/amber fills.
