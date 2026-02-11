## 🚀 Droppy v11.1.0

Sorry from Jordy (the developer). The move to paid could have been introduced more subtly, so v11.1.0 starts with a full **3-day trial** to give everyone a fair chance to try Droppy first.

## ⭐ Biggest updates
- Added a full **3-day Droppy trial**. Try everything free for 3 days, then purchase only if you want to keep it.
- Added an **all-new Calendar split view**:
  - See your current tasks and calendar events side by side in one unified view.
  - Sync is tight and reliable across reminders/tasks and calendar events.
  - Edit tasks on the fly directly from the split view.
- Added stronger licensing enforcement and fixes:
  - Fixed a licensing bug.
  - Closed a seat-limit loophole by applying the same seat-limit check during stored-license verification (not only on new activation).
- Added an **all-new stacked file preview system** for Basket:
  - Updated Basket view with stacked file previews.
  - Updated Basket switcher with stacked files and better responsiveness.
  - Stacked previews keep existing actions intact, including quick copy of dropped files.
  - Task bar now auto-selects when opening the notch.
- Added broad animation/feel upgrades:
  - Improved opening/closing animations for Shelf, Media HUD, and more.
  - Much better lock/unlock animations with smoother transitions and cleaner timing.
  - Improved animation fluidity across Droppy.
  - Stabilized/optimized animations when adding many files to Shelf, including a subtle batch-add animation.

## ✨ Core UX and behavior improvements
- Added notch width controls: make it narrower or wider, with smooth animation and haptics.
- Added per-display auto-expand controls: configure main Mac and external displays separately.
- When **High Alert** is on, hover expansion is disabled (click required), so hover can reliably show remaining High Alert time.
- Updated Finder extension setup flow to be clearer and more visible.
- Replaced the duplicate “Settings” header label with the current section title (for example, “Quickshare”).
- Extension divider/line behavior cleanup:
  - Extension lines now continue fully to the container border.
  - Separator now renders as a neutral vertical line instead of a chevron.
  - When separator is off, hidden delimiter control collapses to zero width.
  - Main toggle icon sets (including chevron icon sets) remain unchanged.
- Cleaned up multiple extension windows.
- Removed forced auto-rename after folder creation (no misleading immediate-cancel flow).
- Added missing **Show in Finder** action to shelf item context actions.
- Fixed shelf auto-collapse behavior so it uses geometric hover + expanded-content hover (not stale notch-hover state).
- Added local + global ESC monitors so Escape works regardless of key-window focus.
- Fixed menu bar click-through with expanded shelf by allowing top-strip pass-through outside the notch trigger area.

## 📤 Quickshare and sharing
- Quickshare now uses a more defensive upload pipeline (including directory handling and guaranteed state cleanup), fixing failed uploads.
- Added Quickshare option to require confirmation before uploading.
- Quickshare now accepts links.
- Fixed sharing files via mail in Outlook (now opens a prefilled mail with the file attached).

## 📸 Capture, OCR, and media pipeline fixes
- Fixed Element Capture flow; area capture, full-screen capture, and OCR capture now work reliably.
- Region/OCR overlay now forces a crosshair cursor while active, giving a clear selection-mode indicator.
- Improved OCR reliability and result routing to the same display where capture was taken.
- Added explicit feedback when OCR detects no text.
- Fixed screenshot editing so it now saves the correct image.
- Fixed AI background removal visibility/output issues.
- Fixed long voice-transcription overlay behavior:
  - No longer auto-hides after 60s during long jobs.
  - Added persistent processing status + elapsed time in manager and overlay UI.

## 🎛️ Display, HUD, and device integration
- Implemented #191: hardware DDC/CI external-display volume control with fallback to existing system-volume path.
- Implemented Lunar compatibility fix in `BrightnessManager` so Droppy can surface HUD updates from polled brightness deltas while keeping normal polling quiet to avoid auto-brightness noise.
- Fixed #194: stabilized built-in display brightness step math so float residue can’t cause a phantom extra 0 step.
- Fixed #198: targeted notch-centering fix for external-primary-display setups.
- Fixed external HUD reveal race where percentage text appeared before notch expansion.
- Fixed lock-screen HUD jumping position after docking/undocking.
- Much better lock/unlock lock-screen HUD animations with smoother transitions.

## 📷 Notchface and Reminders upgrades
- Notchface now uses smarter camera discovery (external/USB cameras first, then fallback).
- Added manual camera picker in Notchface extension window.
- Fixed Reminders extension calendar-permission flow.
- Added the all-new calendar view in Droppy.
- Fixed ToDo permission retry focus-steal path so background Reminders/Calendar sync retries no longer pull focus while typing in other apps.

## 🧠 Stability and quality fixes
- Fixed a critical long-run memory leak in Menu Bar Manager.
- Fixed Menu Bar Manager settings sheet sizing on small displays by constraining height to visible screen bounds.
- Fixed drag-out-of-shelf behavior that could incorrectly trigger basket/switcher prompts.
- Improved basket quick-action reliability.
- Fixed basket/shelf file shortcut behavior (Cmd+A, click-outside deselect, Shift-select).
- Favorited/flagged clipboard entries now always appear correctly.
- Tag manager in Clipboard now adapts to the active color scheme correctly.
- Fixed mini-player reappearance caused by noisy media updates resetting `mediaHUDFadedOut`.
- Implemented #196 in `MusicManager.swift`: debounced track-change path now preserves duration/elapsed values correctly.
- Locked down automatic/background window presentation paths so they wait until Droppy is active/frontmost (while keeping intentional user-triggered activations working).
- Fixed Notify Me overlay interaction blocking so it no longer blocks a large area of the screen.
- Added scrolling file names on Shelf items so long names are visible on hover.

## 📚 Previous release notes (v11.0.x)
Including the previous v11 release notes here for licensing rollout context.

## 🚀 Droppy v11.0.0

Droppy v11 is one of the biggest updates yet, with major new extensions, big workflow upgrades, and a full quality pass across performance, animations, and UI consistency.

## ✨ New
- External brightness and volume controls for connected displays.
- Full light mode support, including a brand-new transparency mode for light appearance.
- New **Reminders** extension with native Apple Reminders + Calendar sync, natural language task creation, correct list routing, and full two-way live sync (create/edit/delete).
- New **Notchface** extension to preview your camera directly from the notch.
- Major Window Snap expansion:
  - Modifier-based pointer drag/resize engine.
  - Live snap-zone preview with commit on mouse-up.
  - Excluded-app support.
  - Optional bring-to-front behavior.
  - Classic and closest-corner resize modes.
  - Persistent defaults for pointer mode, modifier masks, bring-to-front, resize mode, and excluded bundle IDs.
- New option to auto-copy OCR results in shared features.
- New mouse gesture support in the notch with configurable modifiers (Shift/Cmd/Control) to navigate between views like Media HUD and Shelf.
- New setting to choose the default mail app used by quick actions (also supported in Basket).
- New multi-basket support with custom-colored top handlers.
- New basket switcher (Cmd+Tab-style), with instant basket opening, quick basket creation, and customizable shortcut.
- New onboarding option to fully skip analytics (no installs, no reviews, no tracking).
- New option to completely disable quick actions.
- New Terminotch setting to choose which terminal app opens for full terminal mode.
- New per-extension HUD settings for Notify Me, Termi-notch, High Alert, and Notchface.
- New battery HUD with a complete visual redesign.

## 🔧 Improvements
- Element Capture screenshots are now full quality (crisp, lossless-looking output).
- AirPods/headphones animations have been upgraded for a more premium feel.
- Connected earphones/AirPods now appear directly in the volume HUD.
- Animations across the app were revamped for smoother and more efficient motion.
- Extension icons were updated to remove pixelation and improve sharpness.
- Visualizer size was reduced to better match album art and feel more cohesive.
- HUD system refresh:
  - More premium Caps HUD.
  - Improved battery animations.
  - Updated DND HUD.
  - Expanded media player now shows the updated HUD styles.
- Extension action flow was cleaned up by replacing ambiguous labels (like “Get”) with clear state-based actions (Install, Disable, Manage).

## 🧹 Cleanup, Stability, and Fixes
- Removed unused settings and old/dead code.
- Fixed clipboard tags manager appearance consistency across light, dark, and transparency modes.
- Added many crash fixes, bug fixes, and polish improvements across Droppy.

## 🔐 New Licensing System
Droppy now includes a built-in licensing system to support long-term development and maintenance. Licensing is now integrated directly in the app settings flow.
