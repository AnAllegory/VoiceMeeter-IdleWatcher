# Changelog

All notable changes to the repository are documented here.

The v1.0.0 release was published on 2026-11-19. Entries are grouped by release.

## [Unreleased]

### Changed

- Made Error-level PSScriptAnalyzer findings fail the GitHub Actions workflow; Warning and Information findings remain visible but non-blocking.
- Added `AGENTS.md` and `SECURITY.md` to the CI required-file check so repository review and security policies cannot disappear unnoticed.
- Added a Windows Script Host check for the VBS launcher. It verifies script parsing and invalid-argument handling without starting the watcher.


## [1.0.1] - 2026-11-19

### Fixed

- After a recovered VoiceMeeter API login, the connection-warning flag no longer suppresses the next real status line or reports a restored connection immediately.
- Limited unconfirmed `Command.Shutdown` repeats to three successful API calls per engine run. A later confirmed stop and restart gets a fresh limit. Idle and display checks are unchanged. When the limit is reached, the watcher logs one `WARN` and records subsequent suspended retries only at `DEBUG` level.

### Changed

- The PowerShell check no longer requires MacroButtons logical ID 1. STATEONLY, no readback, and the refresh event remain required.

### Documentation

- Updated `PROJECT_CONTEXT.md` with the current source-file sizes, line counts, and repository handover details.
- Removed maintainer-specific MacroButtons button assignments from the general documentation; clarified that the logical button ID is configurable and depends on the local layout.
- Aligned the English and Russian README files and architecture notes with the configurable MacroButtons button-ID description.
- Kept the published `v1.0.0` release notes and tag snapshot unchanged.

## [1.0.0] - 2026-11-19

### Fixed

- Clarified intentional best-effort exception handling and added a warning log when single-instance mutex release fails during startup cleanup.
- Simplified MacroButtons synchronization to assert the watcher's known process state with VBVMR_MacroButton_SetStatus in STATEONLY mode, rather than relying on button-state readback. Added an auto-reset event so a repeated START request immediately refreshes the already-running watcher's button.

### Changed

- Renamed `Set-StartupStatus` to `Write-StartupStatus` to describe its file-writing responsibility accurately; no startup-status behavior was changed.
- Generalized local working-directory examples in documentation so they do not expose maintainer-specific Windows paths.
- Updated MacroButtons documentation to reflect successful local STATEONLY synchronization testing.

### Added

- Added the MIT License.
- Added optional MacroButtons displayed-state synchronization for VoiceMeeter Remote API logical button ID 1 (ID 0 is reserved for the microphone button). The watcher uses VBVMR_MacroButton_SetStatus with STATEONLY, reasserts ON every 10 seconds, and attempts to set OFF during graceful cleanup. A repeated START request signals the running watcher for an immediate refresh. API/button unavailability is non-fatal and only reported in DEBUG mode.
- Added a GitHub Actions workflow that runs on Windows PowerShell 5.1, checks required project files including the license and release notes, parses the main PS1 source, and reports PSScriptAnalyzer findings in baseline mode.
- Added prepared v1.0.0 release notes.

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
