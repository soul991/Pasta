# Pasta Phase 10B: Sticky Wheel, Clipping Fix, Wheel Redesign, Customization, Liquid Glass

*Instructions for the AI coding agent. Date: November 1, 2026. Supersedes any earlier wheel behavior notes where they conflict. Read all of it before writing code.*

## 0. Context: first real-Mac test results

The owner tested the build on a real Mac (screenshot reviewed). The tool works and is fast. Four defects and requests came out of it:

1. **Wheel closes when Shift is released.** The owner wants it to **stay open until Esc**. CI passed the "latches" tests, so the real event path differs from the tested path. This must be investigated, not assumed.
2. **Clipped active node.** The highlighted MKV pill has a straight vertical edge on its right side and a rectangular glow boundary. The node and its glow are cut off by a rectangle (the panel or a view bound).
3. **No real wheel design or branding.** The screenshot shows eight loose dark pills at uneven spacing: no ring, no hub, no backplate, no Pasta mark. The owner wants a premium Liquid Glass design.
4. **No customization.** The owner wants: appearance theme colors, a choice of which tools are the primary ones on the wheel, and a "More" section with extra tools.

## 1. Working rules (unchanged and strict)

- The dev machine is Windows. Label anything you cannot run as "written, NOT compiled or run (Windows)". Real results come only from GitHub Actions logs or from the owner's Mac. Never write "verified" without a log line.
- One commit per step, CI green after each, paste the real log lines for new tests.
- Compacts stay: zero network calls, zero third-party Swift dependencies, no private or undocumented API, no shell concatenation, no silent failures.
- List every fix requested in this document in your report, even if already done.
- Do not start a step until the previous step's CI run is green and reported.

## 2. Step 0: re-verify the previous phase and fix leftovers

1. Paste the latest CI counts (unit and both Section 8 runs).
2. Confirm that Fixes A to D from the batch review (per-file parameters, concurrency limit of 2, cancel for queued jobs, probe off the main thread) landed, with the commit hash and the test names that prove each. If any is missing, fix it first.
3. Confirm `docs/PROGRESS.md` matches reality.
Report before continuing.

## 3. Step 1: sticky wheel (stays open until Esc)

### 3.1 Find the real cause first
Add diagnostic logging (PastaLogger, to `~/Library/Logs/Pasta/`) for every `DragMonitor` event and state change: event type, modifier flags, timestamp, old state, new state, and the reason a close was triggered. Then inspect, with evidence:
- the default of `stayOpenAfterRelease` and whether the real (non-test) path reads it;
- whether the real `flagsChanged` release event, drag-end, `mouseUp` or a lost drag session calls the close path in `AppDelegate`, the overlay panel or the view controller;
- whether closing happens in code that tests bypass (the tests use an injected clock and fake pasteboard).
State the root cause in the report with the code lines.

### 3.2 Required behavior (final)
- The wheel opens after the 450 ms Shift hold and **stays open regardless of Shift release or the end of the drag**.
- It closes only when: **Esc** is pressed, the user clicks the wheel's close control (×), or the user chooses "Hide wheel" from the menu bar item. Dropping a file elsewhere, releasing Shift, or a second Shift hold must **not** close it.
- **Sticky context:** the files from the drag are remembered while the wheel is open. After the drag ends, clicking a node runs that tool on the remembered files. Dropping files onto a node also works. Starting a new drag with a new Shift hold while the wheel is open replaces the remembered files and keeps the wheel open.
- After running a tool the wheel stays open (setting "Keep wheel open after running", default on). Progress and results appear as compact rows under the wheel, never replacing it.
- Esc must work while a different app is frontmost. The panel is non-activating, so key handling needs a global and a local event monitor. If the global key monitor needs Input Monitoring on macOS, detect that and add it to the permission onboarding screen with a clear explanation; do not silently fail.
- If no files are remembered (wheel opened by other means), show "Drag a file onto the wheel" in the hub.

### 3.3 Tests
Add tests that replay **real-shaped event sequences** (not just state calls): shiftDown, hold 450 ms, open, drag continues, shiftUp (a flagsChanged with empty modifiers), mouseUp, wait 5 s: still open. Then click a node: runs on remembered files. Esc: closes and clears remembered files. Second Shift hold: stays open and replaces files. Drop outside: stays open. Also test that the `stayOpenAfterRelease` default is on and is honored by the production path.

### 3.4 Manual checks for the owner
Add to `docs/MANUAL_CHECKS.md`: hold Shift, release, wheel remains; drop on empty desktop, wheel remains; click a node; Esc closes. Include the log path so the owner can send the log if it still fails.

## 4. Step 2: fix the clipped node and glow

**Cause to confirm:** the active node scales up and its glow extends past the panel frame or the hosting view bounds, so it is clipped by a rectangle.

**Required fix:**
- Size the panel as: wheel outer diameter plus 2 times (maximum glow radius + shadow radius + 6% node scale overflow + 8 pt safety). Nothing visible is ever drawn outside the panel.
- Disable clipping (`masksToBounds = false`, `clipsToBounds = false`) on every ancestor of any glow or shadow layer.
- If the wheel is near a screen edge, move the whole wheel inward so the full panel stays on screen; never clip it against the screen or the menu bar.
- Add a headless geometry test: for each of the 8 nodes at hover scale 1.06 with the glow radius, compute the extents and assert they are inside the panel bounds with at least 8 pt margin. Also test the screen-edge repositioning for all four edges and corners.
- Manual check: hover and drop over each node in all positions of the screen (corners and edges), looking for any straight cut edge.

## 5. Step 3: wheel redesign (layout and structure)

Build the wheel as a true circle, not loose pills. Use these exact numbers unless the owner changes them:

- **Backplate:** a circular glass annulus, outer diameter 400 pt, inner (hub) diameter 128 pt. A 1 pt hairline outer stroke with a gradient (top-left `white 0.45` to bottom-right `white 0.08`), and a soft inner shadow.
- **Slots:** 8 evenly spaced positions at 45 degree steps, starting at -90 degrees (top), on a ring radius of 148 pt.
  - Slots 1 to 6: **primary tools** (user-chosen, with defaults per file category).
  - Slot 7: **More** (ellipsis glyph).
  - Slot 8: **Customize** (gear glyph).
- **Nodes:** 64 pt circular glass buttons with a glyph (SF Symbol or format mark) and a 11 pt label below the glyph inside the circle, or beneath it for long names. Labels never clip. Hover scale between 1.00 and 1.06 only.
- **Active node:** accent gradient fill, dark ink label (`#1A0F05` or theme ink with at least 4.5:1 contrast), accent glow `accent @ 0.35`, radius 18, fully inside the panel (see Step 2).
- **Hub:** glass disc 128 pt. When files are remembered: a 64 pt Quick Look thumbnail, name (middle truncation), and "type · size". With several files: a stacked thumbnail and a count. Idle: the Pasta app icon mark, the ridged rigatoni from the new icon (Figma node 16:2), as a flat or lightly shaded glyph (this is the "app icon" presence in the wheel).
- **Connecting wedge:** when a node is hovered, tint the radial wedge from hub to node with the accent at 0.12 alpha.
- **Close control:** a small glass × at the top right of the backplate, 24 pt hit target at least 28 pt.
- **Hint line:** a pill under the wheel: "Esc closes · ⌥ tap switches Convert / Advanced · ⇧ hold re-targets".

### 5.1 "More" section
Choosing **More** expands a second outer ring (diameter 560 pt) or a paged arc, showing every remaining tool for the file category, in pages of 8 with page dots, animated with a spring. Include a quick filter: typing letters filters tools by name. Selecting a tool with parameters opens the existing `ParameterPanelView` (already built), restyled to the glass tokens. Esc closes the More ring first, then the wheel.

### 5.2 Customize section
Choosing **Customize** opens a glass sheet attached to the wheel (not a separate window), with these sections:
1. **Appearance:** theme swatches (Sunset default, Ocean, Emerald, Violet, Rose, Graphite, and "Match system accent"), glass style (Clear, Regular, Tinted) with a strength slider, size (Compact 340, Standard 400, Large 460 pt), labels (always, on hover).
2. **Primary tools:** per category (Image, Video, Audio, PDF, Document, Archive), a reorderable list of exactly 6 pinned slots chosen from all available tools, a toggle to hide a tool, and **Reset to defaults**.
3. **Behavior:** hold duration slider (300 to 1000 ms), keep wheel open after running, show charging ring.
Changes apply live to the wheel and persist in `PreferencesManager`.

### 5.3 Headless model and tests
Add `WheelLayoutModel` (PastaCore, no UI): per-category pinned tools, slot assignment, More contents (everything not pinned and available for that file via `FormatRegistry`), theme selection, persistence, defaults, and migration. Tests: defaults per category; exactly 6 pinned; reorder; hide; reset; persistence round trip; More = all minus pinned; unavailable tools (missing optional binary) excluded; theme contrast: every theme's label-on-accent ratio is at least 4.5:1 (compute it in the test).

## 6. Step 4: Liquid Glass rendering and visual quality

**Goal:** a premium, iOS and macOS Liquid Glass look: translucent refractive surfaces, soft specular edges, depth, restrained color.

- **macOS 26 and later:** use the system glass (`NSGlassEffectView` for surfaces, `NSGlassEffectContainerView` so neighboring nodes merge and morph) behind `#available(macOS 26, *)`. **Do not guess API names:** check them against the SDK on the CI runner (print `xcodebuild -version` and the SDK in the log), and use a compile-time guard (`#if compiler(>=6.2)` or the correct check) so the code still builds on older SDKs.
- **Fallback (macOS 14 and 15, or older SDKs):** `NSVisualEffectView` (`.hudWindow`, behind-window) plus layered Core Animation: a top-left specular edge highlight (gradient stroke), a subtle inner shadow, a faint top sheen gradient, and a 1 pt gradient hairline. No private API.
- **Wallpaper adaptive:** the wheel must be legible over the red wallpaper in the owner's screenshot and over white and photographic wallpapers. Add a subtle adaptive scrim behind labels (at most 0.35 alpha). Test legibility by rendering the wheel over several background colors (headless snapshot test comparing computed contrast).
- **Accessibility:** Reduce Transparency produces an opaque dark surface with the same layout; Increase Contrast strengthens strokes; Reduce Motion removes springs and glows pulse; VoiceOver labels on every node, hub, close and More controls; keyboard: arrow keys move between nodes, Return runs, Tab cycles sections.
- **Motion:** spring physics via `CASpringAnimation` (spatial: damped with slight overshoot; color and opacity: critically damped). Open animation under 220 ms. 60 fps: no more than two live blur layers.
- **References:** if the owner provides a Figma link to a Liquid Glass UI kit, read it with the Figma tools (`get_design_context`) and record the node links used in `docs/DESIGN_REFERENCES.md`; otherwise base the look on Apple's published Materials and Liquid Glass guidance. Do not copy any third-party assets.
- **Tokens:** extend `theme_tokens.json` with the theme palettes, glass strengths, sizes, radii, and spring values, and keep `ThemeManager` as the single source.

## 7. Step 5: brand presence

- The menu bar item must use the template glyph `MenuBarIcon.pdf` and be visible in light and dark menu bars. Verify in code that the `NSStatusItem` button image is set, marked as template, and sized 18 pt. If the owner cannot see it, log why.
- Show the Pasta icon in the wheel hub (idle), in the Settings header and in an About panel.
- Keep `AppIcon.icns` in the bundle; confirm `CFBundleIconFile` is set in `Info.plist`.

## 8. Step 6: finish remaining Phase 10

After Steps 1 to 5 are green: results and errors (progress rows with ETA and Cancel, real size change from the files, Reveal in Finder, readable errors with Copy details, unsupported and empty states), and first-run Accessibility onboarding plus Settings (the Customize sections above also appear in Settings). Settings and Customize share the same model.

## 9. Gate for the whole block

- Every step green in CI with real log lines; counts reported.
- Section 8 still passes for both the debug binary and `Pasta.app`.
- New tests listed in sections 3.3, 4, 5.3 and 6 exist and pass.
- `docs/MANUAL_CHECKS.md` updated with: sticky wheel, no clipping at all positions and screen edges, node hover and drop, More ring, Customize changes persisting after relaunch, theme switching, Reduce Transparency, Reduce Motion, VoiceOver, menu bar glyph, light and dark wallpapers.
- The owner will test on the Mac and send a screenshot and the log file; do not claim the visual result is right until the owner confirms.

## 10. Step 7: new app icon (rigatoni)

The owner approved a new icon direction: a ridged rigatoni on a tangerine squircle. Do **not** redraw it. Use the Figma tools to export node 16:2 (file key bocBCCWoX3YUHX3qBJX3WQ, page "Pasta App Icon", frame "Pasta Icon v2 / Rigatoni Wheel 1024") as a 1024 PNG, build the iconset and `AppIcon.icns` from that PNG, and create a matching menu bar template glyph (solid diagonal rigatoni silhouette, 18 and 22 pt, PDF, template rendering). If you cannot export from Figma, say so; never substitute your own drawing. Report the CI log lines for the bundle contents.
