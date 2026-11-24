# VoiceMeeter IdleWatcher — Project Roadmap

This document records the current project state, possible follow-up observations and deliberate scope decisions. It is a planning note, not a promise that every item will be implemented.

The latest official GitHub Release remains v1.0.5; the v1.0.6 tag and GitHub Release page are still pending. The v1.0.6 source is merged into `main` through PR #13 and passed static CI plus maintainer-reported target-PC runtime validation on 2026-11-24. Its Portable ZIP is published on `gh-pages` and the website links directly to the GitHub-hosted archive. Known issue: Microsoft Defender detected the downloaded ZIP as `Trojan:Script/Wacatac.H!ml` on the maintainer's Windows 11 PC and quarantined it; a separate custom scan of the installed application folder produced no recorded detection. This does not establish a false positive, and the cause remains unresolved. Keep this warning visible and do not advise users to disable Defender or restore quarantined copies. The public project and the project relationship are described in REPOSITORY_LINEAGE.md. Changes should be driven by reproducible behavior, a concrete use case or a clear maintenance benefit. Do not add complexity merely because it is technically possible.

## Implemented in the modular development line

### Modular transition — v1.0.2

- Split the monolithic watcher responsibilities into the orchestrator, PSD1 configuration, Support, Interop and MacroButtons modules, native C# interop and VBS launcher.
- Kept Windows PowerShell 5.1 as the required runtime.
- Preserved the established idle/display shutdown safety model and graceful start/stop flow.

### Safety and diagnostics hardening — v1.0.3

- Fixed STATEONLY (0x00000002) inside the MacroButtons module.
- Added bounded configuration validation and explicit handling for known API absence versus unknown API errors.
- Strengthened the shutdown validation and graceful cleanup behavior.
- Preserved one MacroButtons writer and the no-readback rule.

### Pre-shutdown display allowance — v1.0.4

- Added a 1000ms allowance after a successful STATEONLY OFF write.
- Moved final idle, display and /stop checks after the allowance and immediately before Command.Shutdown.
- Kept MacroButtons optional and non-fatal.

### No-server write gate — v1.0.5

- Periodic and manual-refresh MacroButtons writes now require both a known API state and a confirmed running engine.
- After IsParametersDirty = -2 confirms server teardown, the watcher retains the last accepted indicator state rather than sending futile writes.
- Startup/recovery paths no longer attempt OFF when Login indicates that no VoiceMeeter engine is running.

### Maintenance diagnostics and logging cadence — v1.0.6

- The diagnostic `Desired` summary reports OFF only when a pre-shutdown OFF write was accepted; a confirmed-stopped engine without such an accepted write is reported as writes paused with the last accepted state retained.
- The temporary pending-shutdown marker is cleared when engine stop is confirmed, preventing a completed shutdown from remaining labelled as pending.
- Status snapshots are emitted on the first main-loop pass and then at intervals of at least 300 seconds. The main monitoring loop and default MacroButtons synchronization cadence are unchanged.
- CI now checks the v1.0.6 candidate version, diagnostic summary semantics, pending-marker cleanup and snapshot interval/immediate-first-snapshot contracts.
- The source and Portable ZIP are now published on `main` and `gh-pages`, respectively. The v1.0.6 tag and GitHub Release remain pending; v1.0.5 is still the latest official GitHub Release. The Defender detection of the downloaded ZIP remains an unresolved publication notice.

## Current observations

These are observations, not confirmed defects requiring immediate code changes.

### 1. MacroButtons visual timing

The maintainer's v1.0.5 test on 2026-11-22 confirmed the OFF command acceptance, 1000ms allowance, final safety validation, successful Shutdown and confirmed engine stop. After waking the PC, the maintainer saw button 1 OFF and VoiceMeeter not running.

The exact instant when the visible button extinguished relative to engine shutdown was not directly observed because the display was Off during that interval. The writer intentionally has no UI readback. No change to the delay is justified by the current evidence alone.

### 2. Rapid engine availability transitions

A short engine start/stop sequence was observed in the maintainer's log. The watcher logged the API becoming available and later unavailable, and retained the last accepted state when the server disappeared.

Continue normal observation. Revisit only if a reproducible rapid-restart scenario leaves the indicator or watcher state inconsistent.

### 3. Remote Desktop behavior

An RDP session disconnect may be represented to the session as display Off. If the maintainer adopts RDP and this behavior becomes undesirable, define expected behavior for connected, disconnected and reconnected sessions before changing the shutdown gate.

### 4. Sleep / Wake behavior

The current design does not implement a dedicated Sleep / Wake state machine. The latest test did confirm normal display-On handling after the PC was awakened, but it does not prove every sleep/resume configuration. An independent review raised a possible event-ordering window around resume, but no repeatable failure has been demonstrated. Add dedicated handling only if a repeatable problem is found.

### 5. Logging clarity

If a real troubleshooting case needs it, consider making the origin and reason for START / STOP requests easier to identify. Avoid adding high-volume logging without a concrete diagnostic benefit.

### 6. Graceful stop after Shutdown dispatch

A review raised a possible transient where /stop arrives after Command.Shutdown has been dispatched but before the Remote API reports the engine as stopped. Cleanup may still see the API as available and accept an ON write while the engine is already stopping. This has not been reproduced and does not currently justify changing cleanup behavior. Observe it on the target PC before proposing a code change.

### 7. VoiceMeeter starts while idle and display Off

A review identified a scenario worth observing: VoiceMeeter starts while the idle threshold is already satisfied and the display is Off, so the watcher may assert ON and then proceed through its normal OFF/allowance/final-check/Shutdown sequence. No unsafe behavior has been demonstrated. Verify the intended indicator behavior during a target-PC test before changing the state flow.

## Deliberately out of scope for now

Do not add these without a reproducible requirement and a separate design decision:

- VoiceMeeter process polling, WMI subscriptions or Process.Exited handlers.
- A second independent MacroButtons writer or helper process.
- GetStatus readback or MacroButton_IsDirty polling in the watcher.
- A configurable STATEONLY bitmode.
- DLL selection based on guessed VoiceMeeter process bitness.
- Audio signal-level monitoring or sound notifications.
- An external configuration surface, WhatIf mode or extra operating modes without a concrete use case.
- More elaborate log rotation without demonstrated log-management problems.
- Broad architectural refactoring for style alone.

## Working principles

1. Fix demonstrated problems, not hypothetical ones.
2. Preserve fail-safe behavior: On, Dimmed, unknown or unavailable display state must not permit automatic shutdown.
3. Preserve final idle/display/stop revalidation immediately before Command.Shutdown.
4. Keep MacroButtons optional, with one STATEONLY writer and no readback.
5. Treat maintainer runtime observations separately from source inspection and static CI.
6. Keep Windows PowerShell 5.1 compatibility and the existing DLL marker/import-order contracts.
7. Do not create or modify public release tags or published releases during routine source development; release operations are separate and require explicit maintainer approval.
8. Do not create a numbered release merely to make progress on this roadmap.

## Published release v1.0.5

The maintainer published **v1.0.5** as the latest stable GitHub Release on 2026-11-22. The tag points to the validated source commit `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`. The release is not marked as a pre-release, and GitHub generated its tag-based source archive links automatically.

- [x] Modular source integrated into public `main` through PR #10.
- [x] Static Windows PowerShell 5.1, project-contract and C# checks passed on the release commit.
- [x] Maintainer-reported target-PC test completed on 2026-11-22: STATEONLY OFF accepted, 1000ms allowance elapsed, final safety validation passed, Command.Shutdown returned code 0 and engine stop was confirmed.
- [x] English and Russian README files, CHANGELOG, project handover and version-specific release notes published.
- [x] GitHub Pages distinguishes the current `main` source snapshot from tagged releases and links to the versioned release history.
- [x] Published as the latest stable release with a linked Announcements discussion: [v1.0.5 discussion #11](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/discussions/11).

The private Beta workspace should remain an archive unless there is a separate reason to continue development there.

## Status

The v1.0.2 through v1.0.5 implementation work is integrated into public `main`. PR #10 was merged on 2026-11-22, and the v1.0.5 release was published on the same date. PR #13 was merged on 2026-11-24. The v1.0.6 source passed static CI and the maintainer-reported target-PC runtime test; the Portable ZIP is prepared. Creation of the v1.0.6 tag and GitHub Release is the remaining publication action. The v1.0.5 tag remains a snapshot of the validated source commit; later source or documentation changes do not alter that published tag.
