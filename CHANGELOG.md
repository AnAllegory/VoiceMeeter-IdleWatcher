# Changelog

All notable changes to the repository are documented here.

The first numbered release is being prepared. Until the v1.0.0 tag and GitHub Release are published, entries below describe the current release candidate, not a published release.

## [Unreleased]

### Fixed

- Clarified intentional best-effort exception handling and added a warning log when single-instance mutex release fails during startup cleanup.
- Simplified MacroButtons synchronization to assert the watcher's known process state with VBVMR_MacroButton_SetStatus in STATEONLY mode, rather than relying on button-state readback. Added an auto-reset event so a repeated START request immediately refreshes the already-running watcher's button.

### Changed

- Renamed `Set-StartupStatus` to `Write-StartupStatus` to describe its file-writing responsibility accurately; no startup-status behavior was changed.

### Added

- Added the MIT License.
- Added optional MacroButtons displayed-state synchronization for VoiceMeeter Remote API logical button ID 1 (ID 0 is reserved for the microphone button). The watcher uses VBVMR_MacroButton_SetStatus with STATEONLY, reasserts ON every 10 seconds, and attempts to set OFF during graceful cleanup. A repeated START request signals the running watcher for an immediate refresh. API/button unavailability is non-fatal and only reported in DEBUG mode.

- Added a GitHub Actions workflow that runs on Windows PowerShell 5.1, checks required project files, parses the main PS1 source, and reports PSScriptAnalyzer findings in baseline mode.

### Changed

- Generalized local working-directory examples in documentation so they do not expose maintainer-specific Windows paths.
- Updated MacroButtons documentation to reflect successful local STATEONLY synchronization testing.

Changes made after the latest dated entry will be recorded here.

## [Repository baseline — 2026-11-18]

### Added

- Added the current PowerShell watcher source: `VoiceMeeter-IdleWatcher.ps1`.
- Added the VBScript launcher and stop controller: `VoiceMeeter-IdleWatcher.vbs`.
- Added English and Russian project guides: `README.md` and `README.ru.md`.
- Added `PROJECT_CONTEXT.md` as a maintainer handover document for restoring project context and recording verified behavior, known limitations, and working preferences.
- Added `ARCHITECTURE.md` with bilingual Mermaid diagrams and a high-level explanation of the monitoring, safety checks, shutdown request, and graceful-stop flow.
- Added `.gitignore` rules for runtime logs, temporary files, local backups, KeePassXC databases, and Windows Explorer metadata.

### Notes

- This entry records the initial documented repository baseline, not a numbered software release.
- Runtime behavior was verified on the maintainer's target Windows system for the reported baseline scenarios; long-duration operation and sleep/wake recovery remain under observation.
- MacroButtons visual-state synchronization is implemented with STATEONLY and has been confirmed in local runtime testing.
- The project is licensed under the MIT License.
