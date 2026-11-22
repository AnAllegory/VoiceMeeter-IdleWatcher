# VoiceMeeter IdleWatcher — Project Roadmap

This document records the current project state, possible follow-up observations and deliberate scope decisions. It is a planning note, not a promise that every item will be implemented.

The current integrated modular source baseline is v1.0.5. The public project and the project relationship are described in REPOSITORY_LINEAGE.md. Changes should be driven by reproducible behavior, a concrete use case or a clear maintenance benefit. Do not add complexity merely because it is technically possible.

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

The current design does not implement a dedicated Sleep / Wake state machine. The latest test did confirm normal display-On handling after the PC was awakened, but it does not prove every sleep/resume configuration. Add dedicated handling only if a repeatable problem is found.

### 5. Logging clarity

If a real troubleshooting case needs it, consider making the origin and reason for START / STOP requests easier to identify. Avoid adding high-volume logging without a concrete diagnostic benefit.

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

## Public release preparation

The modular v1.0.5 source has been merged into the canonical public main branch through PR #10. Before a new public release:

- Confirm that the merged main branch contains the intended modular source and that its default-branch CI validation succeeds.
- Before packaging, perform a fresh target-PC check from a clean checkout of main and document exactly what was observed.
- Select the next public version number. Internal v1.0.2-v1.0.5 milestones are not public tags.
- Prepare version-specific release notes and a distribution ZIP containing the required source files.
- Keep GitHub Pages synchronized with the current source layout and clearly distinguish the main-branch source snapshot from the latest published release.
- Create the tag and GitHub release only after the maintainer explicitly approves publication.

The private Beta workspace should remain an archive unless there is a separate reason to continue development there.

## Status

The v1.0.2 through v1.0.5 implementation work described above is integrated into public main. PR #10 was merged on 2026-11-22; the main automatic-shutdown path was exercised by the maintainer on that date. Remaining items are observations or future considerations, not active code-change tasks.
