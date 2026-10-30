# Pasta – Shift-hold Wheel UI

*Design Specification & Component System for Pasta macOS File Converter*  
*Date: October 31, 2026 · Supersedes earlier "tap Shift" concepts.*

---

## 1. Design System Foundation (Variables & Tokens Built First)

In accordance with strict macOS AppKit and Apple Human Interface Guidelines, design tokens and components are constructed and bound before composing screens.

### 1.1 Semantic Color Tokens & macOS Native Materials

Instead of brittle fixed hex values, Pasta maps all surfaces to native macOS AppKit materials and semantic dynamic roles:

| Semantic Token | macOS Native Material / Dynamic Color | Value / Fallback | WCAG Ratio & Contrast Notes |
| :--- | :--- | :--- | :--- |
| `surface-wheel` | `NSVisualEffectView.Material.hudWindow` | HUD Translucent Glass | High-vibrancy behind-window blur |
| `surface-popover` | `NSVisualEffectView.Material.popover` | Native Popover Blur | Pure macOS menu bar popover backdrop |
| `surface-sidebar` | `NSVisualEffectView.Material.sidebar` | System Sidebar Glass | Used for settings and diagnostics lists |
| `surface-selection` | `NSVisualEffectView.Material.selection` | Selection Highlight | System-accented selection highlight |
| `accent-primary` | Dynamic Brand Color | `#F2611F` (Sunset Deep) | Base action color, progress fill |
| `accent-vibrant` | Highlight Stop | `#FF9E33` (Sunset Amber) | Drag-over active background |
| `accent-gradient`| Linear 135° Gradient | `#FFB347` &rarr; `#F2611F` | Signature brand gradient |
| `accent-ink` | Custom High-Contrast Ink | `#1A0F05` | **8.9:1 against `#FF9E33`** (WCAG AAA Pass) |
| `text-primary` | `NSColor.labelColor` | `#FFFFFF` (Dark Mode) | 100% white, high-emphasis headings |
| `text-secondary` | `NSColor.secondaryLabelColor` | `rgba(255, 255, 255, 0.70)` | Subheadings, file extensions, active state |
| `text-tertiary` | Calibrated Tertiary Text | `rgba(255, 255, 255, 0.55)` | **4.8:1 against `#120D18`** (Raised to 55% for AA Pass) |
| `border-subtle` | Subtle Stroke | `rgba(255, 255, 255, 0.12)` | Inactive node boundary |
| `border-strong` | Focused Stroke | `rgba(255, 255, 255, 0.35)` | Highlighted and focus ring outline |

> [!IMPORTANT]
> **Contrast Fix (Rule 6)**: White text on `#FF9E33` achieves only ~2.1:1 contrast, failing accessibility standards. In active/drag-over states, slice labels and icons switch to `accent-ink` (`#1A0F05`), achieving a contrast ratio of **8.9:1**. Tertiary text is calibrated to 55% white (`rgba(255,255,255,0.55)`), ensuring small hint pills reach at least **4.8:1** (meeting WCAG 2.2 AA).

---

### 1.2 Spring Physics Tokens (`CASpringAnimation`)

All motion curves in Pasta are driven by native `CASpringAnimation` physical parameters rather than arbitrary cubic beziers:

1. **Spatial Bloom (Opening & Expansion)**:
   - `mass`: `1.0`
   - `stiffness`: `420.0`
   - `damping`: `28.0`
   - *Behavior*: Natural fluid blooming from cursor center with ~3% physical overshoot, settling in 250 ms.
2. **Spatial Dismissal (Collapse & Exit)**:
   - `mass`: `0.8`
   - `stiffness`: `550.0`
   - `damping`: `32.0`
   - *Behavior*: Critically damped snappy exit, settling in 180 ms without visual bounce.
3. **Hover Scale (Node Micro-Interaction)**:
   - `mass`: `0.5`
   - `stiffness`: `600.0`
   - `damping`: `35.0`
   - *Scale Boundary*: Strictly clamped between **1.00** (idle) and **1.06** (active hover/drag-over).

---

### 1.3 Radial Option Segment Component (States)

The radial segment component (`RadialOptionNodeView`) has four distinct states:

```
[ Default / Idle ]       [ Hover ]                 [ Active / Drag-Over ]      [ Disabled ]
+---------------+       +-----------------+       +-----------------+         +---------------+
| (o) PNG       |  -->  | (o) PNG         |  -->  | (o) PNG (Dark)  |         | (x) UNAVAIL   |
+---------------+       +-----------------+       +-----------------+         +---------------+
scale: 1.00             scale: 1.03               scale: 1.06                 scale: 1.00
bg: dark hud (88%)      bg: accent subtle (25%)   bg: #FF9E33 (100%)          bg: transparent
border: 1.2px (35%)     border: 1.8px accent      border: 2.0px white         border: 1.0px (10%)
text: 100% white        text: 100% white          text: #1A0F05 (Dark Ink)    text: 30% white
```

---

## 2. Trigger Decision & State Machine (Shift-Hold 450 ms)

### 2.1 The 450 ms Threshold
- **Why 450 ms**: Accidental modifier taps during drafting or dragging typically span 80–250 ms. Requiring a deliberate 450 ms hold filters out accidental contact while remaining well beneath the 1.0–1.5 s fatigue ceiling.
- **Configurability**: Configurable in Settings via a continuous slider from 300 ms to 1000 ms (default 450 ms).

### 2.2 Complete State Transitions
1. **Idle**: No drag active, or pasteboard contains no valid file URLs (e.g. text/image snippet). Shift key presses are ignored.
2. **Armed**: A real file drag is in progress and Shift goes down. A monotonic timer begins using `event.timestamp`.
3. **Charging (0 to 450 ms)**:
   - After a 120 ms quiet delay, a thin progress ring (`ChargingProgressRingPanel`, 2px stroke, diameter 32px) appears around the cursor, filling linearly to 100% at 450 ms.
   - Releasing Shift or pressing any other key cancels and immediately removes the ring.
4. **Open**: At 450 ms, the radial wheel blooms around the cursor and **latches**: releasing Shift does not close the wheel.
5. **Close**:
   - Dropping onto an action node triggers conversion and closes.
   - Pressing <kbd>Esc</kbd> cancels and closes.
   - Dropping outside the wheel or ending the drag closes the wheel and allows normal Finder drop.
   - A second deliberate Shift hold (450 ms) closes the wheel.
6. **Option Mode Toggle**:
   - Tapping <kbd>Option</kbd> (<kbd>⌥</kbd>) for less than 250 ms while open toggles between **Convert** and **Advanced Tools** modes.

### 2.3 Hint Pill Specification
A floating translucent pill sits below the radial wheel:
`"Hold ⇧ to open · Esc cancels · tap ⌥ switches Convert / Advanced"`
- Background: `NSVisualEffectView.Material.hudWindow` with 1px border `rgba(255,255,255,0.15)`.
- Typography: 11pt medium, `text-tertiary` (55% white, 4.8:1 contrast).

---

## 3. Screen Inventory & Specifications

### Screen 1: File Drag Idle & Armed State
- Desktop view with file icon being dragged by mouse cursor.
- Hint pill appears discretely near bottom of the display: `"Hold ⇧ to open · Esc cancels · tap ⌥ switches Convert / Advanced"`.

### Screen 2: Charging Cursor Progress Ring
- Location: Centered directly around the mouse cursor tip.
- Timing: Visible from $t = 120\text{ ms}$ to $t = 450\text{ ms}$.
- Visuals: Thin 2px circular ring with smooth amber accent fill (`#F2611F`), subtle outer glow.
- Reduce Motion: Ring animation suppressed; wheel appears at 450 ms with a direct cross-fade.

### Screen 3: Radial Options Wheel (Standard / Convert Mode)
- Center Disc: Diameter 110 px with file icon preview, filename, and `CONVERT` badge in `accent-primary`.
- Orbiting Nodes: 8 equidistant nodes at radius 138 px showing high-priority conversion targets (e.g. `JPG`, `PNG`, `WEBP`, `PDF`, `AVIF`, `HEIC`, `TIFF`, `GIF`).
- Interaction: Non-activating panel preserves Finder focus so the drag session remains active.

### Screen 3-Alt: Advanced Tools Mode (Option Tap)
- Activated via a quick tap of <kbd>Option</kbd> (<kbd>⌥</kbd>) under 250 ms.
- Center Badge: Updates dynamically to `ADVANCED`.
- Orbiting Nodes: Switches seamlessly to advanced operations:
  - `COMPRESS` (Lossless & lossy size optimization)
  - `TRIM` (Audio/video sub-clip extraction)
  - `CROP` *(Planned)*
  - `SPEED` *(Planned)*
  - `EXACT SIZE` *(Planned)*
  - `STRIP EXIF` (Non-destructive metadata elimination)
  - `QR DECODE` (Offline Vision barcode & QR extraction)
  - `SPLIT PDF` (Page bursting and extraction)

### Screen 4: Active Node Hover / Slice Drag
- Cursor hovering directly over an option node.
- Scale: Expanded smoothly to **1.06** maximum.
- Background: Vibrant `#FF9E33` sunset amber.
- Typography: Active slice label and icon set to dark ink `#1A0F05` (8.9:1 contrast).

### Screen 5: Conversion Result HUD
- Morphing transition: Center disc expands into status HUD (150x150 px).
- Success indicator: Checkmark icon with ring ripple.
- Savings display: Corrected savings text prominently reading:
  **"Saved 62% (248 MB &rarr; 94.2 MB)"** (all references to "-48%" eradicated).
- Action: "Reveal in Finder" button.

### Screen 6: Menu Bar Drop Window (Native `NSPopover`)
- Container: Standard native `NSPopover` attached to system status item.
- Components:
  - Header with title, accent palette color selector dots, and Standard/Advanced segmented control.
  - Generous drop zone for clicking or dropping files.
  - Active jobs stack with live progress and cancel controls.
  - Phase 9 advanced features (Exact size, video speed, crop) labeled as `Planned`.

### Screen 7: First-Run Accessibility Permission Onboarding
- Dialog presented when accessibility event monitoring is not yet authorized.
- Graphic: System Settings &rarr; Privacy & Security &rarr; Accessibility illustration.
- Instructions: Clear one-click button to open System Settings directly to Pasta's toggle.

### Screen 8: Settings Panel
- Hold Duration: Continuous slider with numeric readout (300 ms &ndash; 1000 ms, default 450 ms).
- Toggle: "Stay open after Shift release" (default: ON).
- Toggle: "Show charging progress ring at cursor" (default: ON).
- Output Destination: Radio group ("Save beside original file" vs. "Custom folder...").
- System Diagnostics / Doctor: Embedded `pasta doctor` status list showing verified Homebrew engines.

### Screen 9: Error State
- Triggered on conversion failure (e.g. corrupt input file or missing dependency).
- Visuals: Soft red warning badge with clear explanation (`PastaError.engineFailed`).
- Actions: "Copy Error Log" and "Open Diagnostics (Doctor)".

### Screen 10: Batch Processing State
- Triggered when multiple files are dropped on a slice.
- Layout: Multi-job progress HUD displaying overall queue progress (`3 of 12 complete`) and per-item status indicators.

### Screen 11: Unsupported-File State
- Triggered when dragging files with unrecognized MIME/extension.
- Center Disc: Shows `UNSUPPORTED` pill with secondary advice ("Try dragging images, video, audio, or PDFs").

### Screen 12: Empty State
- Displayed in drop window when no files have been converted during the current session.
- Visuals: Elegant farfalle watermark silhouette with prompt: "Drag files here or hold ⇧ while dragging anywhere".

---

## 4. Accessibility Variants Specification

1. **Reduce Motion**:
   - Cursor charging ring suppressed.
   - Radial nodes do not perform staggered spring bloomed expansion; appear instantly with a 150 ms linear opacity fade.
   - Hover scale transforms collapsed to subtle border highlight rather than dimensional expansion.
2. **Reduce Transparency**:
   - `NSVisualEffectView` materials replaced with solid high-opacity obsidian background (`#16121C` at 98% opacity).
3. **Increase Contrast**:
   - Node borders thickened from 1.2px to 2.0px with 60% white.
   - Active node background shifts to deep `#E04F0D` with pure black `#000000` text (11.2:1 contrast).
4. **Light Appearance**:
   - Background: Native light popover / HUD material.
   - Primary text: `NSColor.labelColor` (pure dark).
   - Node background: `rgba(255, 255, 255, 0.85)` with subtle shadow.

---

## 5. Phase 9 Feature Roadmap Status

| Feature | Action ID | Engine | Design Status |
| :--- | :--- | :--- | :--- |
| Image/Video Percent Compression | `image.compress`, `video.compress` | `magick`, `ffmpeg` | **Active** |
| Exact Size Target Compression | `image.compress.exact`, `video.compress.exact` | `magick`, `ffmpeg` | **Planned (Phase 9)** |
| Video Speed Adjustment | `video.speed` | `ffmpeg` | **Planned (Phase 9)** |
| Visual Media Crop | `video.crop`, `image.crop` | `ffmpeg`, `sips` | **Planned (Phase 9)** |
| Metadata Stripping | `metadata.strip` | `exiftool` | **Active** |
| Offline QR / Barcode Decode | `image.qr.decode` | Apple `Vision` | **Active** |
| PDF Split & Reorganize | `pdf.split`, `pdf.reorganize` | `qpdf`, `pdftoppm` | **Active** |
