# Changelog

All notable changes to the repository are documented here.

This project has not yet published a numbered release. Until the first release is explicitly tagged, entries describe repository changes and the current development baseline rather than claims of a released version.

## [Unreleased]

### Changed

- Renamed `Set-StartupStatus` to `Write-StartupStatus` to describe its file-writing responsibility accurately; no startup-status behavior was changed.

### Added

- Added a GitHub Actions workflow that runs on Windows PowerShell 5.1, checks required project files, parses the main PS1 source, and reports PSScriptAnalyzer findings in baseline mode.

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
- Runtime behavior must still be verified on the target Windows system with VoiceMeeter installed.
- MacroButtons visual-state synchronization is not implemented in the current source.
- No software license has been selected.
