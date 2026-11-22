# VoiceMeeter IdleWatcher

[English](README.md) | [Русский](README.ru.md)

A Windows PowerShell utility that monitors user idle time and display power state, then requests VoiceMeeter shutdown only when the configured idle threshold has elapsed and the display is fully Off.

> **Current source baseline:** modular implementation **v1.0.5**, integrated into the public `main` branch. It is not yet a new public release tag; the latest published release remains v1.0.1. See [Releases](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/releases) for published versions.

For the history of the transition from the original monolithic implementation to the modular source, read [REPOSITORY_LINEAGE.md](REPOSITORY_LINEAGE.md).

## Safety model

Automatic shutdown is allowed only when both conditions are true:

1. The configured Windows idle threshold has been reached.
2. The display state is fully Off (0).

Display On (1), Dimmed (2), unknown or unavailable blocks automatic shutdown. Idle, display state and graceful /stop are checked again after the MacroButtons refresh allowance and immediately before Command.Shutdown.

Stopping IdleWatcher does **not** shut down VoiceMeeter. It stops the watcher and performs cleanup.

## Automatic shutdown sequence

When the shutdown conditions are met:

1. The watcher checks idle time, display Off and whether a graceful stop was requested.
2. If MacroButtons synchronization is enabled and the STATEONLY OFF command is accepted, the watcher waits **1000ms** to give the MacroButtons application time to process the changed display state.
3. After the wait, it rechecks idle time, display state and /stop immediately before sending Command.Shutdown.
4. If a safety condition changed during the wait, shutdown is cancelled and the watcher attempts to restore ON when the API is still available.

The 1000ms wait is a refresh allowance, not a readback and not a guarantee that the user interface has visibly updated. If MacroButtons is disabled or the optional OFF write is not accepted, the wait is skipped; MacroButtons failure does not disable the main shutdown feature.

## MacroButtons indicator

The optional indicator uses VBVMR_MacroButton_SetStatus with STATEONLY (0x00000002). The mode is fixed in the module and is not configurable in PSD1. STATEONLY changes the displayed state without executing the button macro.

- Default Remote API logical button ID: 1.
- Set MacroButtonLogicalIndex = -1 in PSD1 to disable synchronization.
- The watcher asserts ON while VoiceMeeter is confirmed available and performs periodic synchronization at the configured interval.
- Before an IdleWatcher-issued automatic shutdown, it attempts OFF while the Remote API is still available.
- During graceful watcher stop, it asserts ON if VoiceMeeter is confirmed available. If the API is unavailable or unknown, it retains the last state accepted by the API.
- The watcher does not read the displayed button state through GetStatus and does not call MacroButton_IsDirty. A successful SetStatus return means the API accepted the command; it is not visual readback.

The status snapshot distinguishes Desired, LastAccepted, WriterStatus and LastAcceptedAt. WriterStatus describes the most recent MacroButtons write result; it is not a live Remote API health indicator. LastAccepted records the last state accepted by the API, not a readback of the visible button.

### Manual VoiceMeeter Exit limitation

When VoiceMeeter is closed manually, the watcher may learn that the engine/API has stopped only after the Remote API server is already unavailable (IsParametersDirty = -2). It cannot send STATEONLY OFF through a server that has disappeared, so the last accepted indicator state may remain ON. This is an accepted API lifecycle limitation. When VoiceMeeter becomes available again, the watcher asserts ON.

The project deliberately does not add process polling, WMI subscriptions, Process.Exited handlers or a second MacroButtons writer to work around this limitation.

## Modular source layout

| File | Responsibility |
|---|---|
| VoiceMeeter-IdleWatcher.ps1 | Main orchestrator, configuration validation, monitoring loop and shutdown flow |
| VoiceMeeter-IdleWatcher.psd1 | Runtime configuration |
| VoiceMeeter-IdleWatcher.vbs | Hidden launcher, startup status and graceful /stop |
| VoiceMeeter-IdleWatcher.Support.psm1 | Logging, startup-status and stop/refresh support |
| VoiceMeeter-IdleWatcher.Interop.psm1 | DLL discovery, C# source preparation and Remote API setup |
| VoiceMeeter-IdleWatcher.MacroButtons.psm1 | Single STATEONLY writer and last-write status |
| VMRIdleWatcherNative.cs | Windows and VoiceMeeter native interop |

The import order is Support -> Interop -> MacroButtons. Keep the implementation files together in the same application folder.

## Configuration defaults

The configuration file is VoiceMeeter-IdleWatcher.psd1.

| Setting | Default | Meaning |
|---|---:|---|
| IdleMinutes | 8 | Idle threshold in minutes, allowed range 1–60 |
| CheckIntervalSec | 10 | Main monitoring interval |
| RetryIntervalSec | 30 | Retry interval after relevant API errors |
| ShutdownCommandLimit | 3 | Maximum successful, unconfirmed Shutdown commands per engine run |
| MacroButtonLogicalIndex | 1 | Remote API logical button ID; -1 disables the feature |
| MacroButtonSyncIntervalSec | 10 | Periodic indicator assertion interval |
| DebugMode | false | Set to true for per-probe, per-write and detailed loop traces |

Other timing, timeout, log-size and synchronization-object values are also validated in PSD1. Invalid configuration is logged as a startup failure. MacroButtons failures remain non-fatal.

## Requirements

- Windows.
- Windows PowerShell 5.1.
- VoiceMeeter installed with its Remote API DLL.
- Windows Script Host enabled for the VBS launcher.

The DLL is selected for the **PowerShell watcher process architecture**: 64-bit PowerShell uses VoicemeeterRemote64.dll; 32-bit PowerShell uses VoicemeeterRemote.dll.

## Start and stop

Keep the PS1, PSD1, VBS, modules and C# source in one directory.

Start the watcher hidden:

```text
wscript.exe VoiceMeeter-IdleWatcher.vbs
```

Stop it gracefully:

```text
wscript.exe VoiceMeeter-IdleWatcher.vbs /stop
```

The launcher waits for explicit startup status. Graceful stop signals the existing watcher, which logs out of the Remote API, unregisters display notifications, closes event resources and releases the single-instance mutex. Do not use process termination as the normal stop method.

## Validation status

The modular v1.0.5 source baseline previously passed the Windows PowerShell 5.1 parsing, project-contract and C# compilation workflow in the private development workspace. This repository's workflow runs those checks against the modular source and also validates the VBS invalid-argument path and runs PSScriptAnalyzer 1.25.0 over the orchestrator and PowerShell modules. Error-level analyzer findings fail CI; Warning and Information findings are reported but do not block it. These checks are static: they do not run VoiceMeeter or inspect the MacroButtons UI.

The maintainer also reported a successful v1.0.5 automatic-shutdown cycle on the target PC on 2026-11-22: OFF was accepted, the 1000ms allowance elapsed, final safety validation passed, Shutdown returned code 0 and the engine stop was confirmed. After waking the PC, the maintainer observed MacroButton 1 OFF and VoiceMeeter not running. The exact visual instant at which the button extinguished before engine shutdown was not directly observed while the display was Off. See PROJECT_CONTEXT.md for the timestamps and evidence boundaries.

## Documentation

- [Repository history and modular integration](REPOSITORY_LINEAGE.md)
- [Security policy](SECURITY.md)
- [Project roadmap and deliberate scope](ROADMAP.md)
- [Architecture and control flow](ARCHITECTURE.md)
- [Change history](CHANGELOG.md)
- [Maintainer handover and runtime evidence](PROJECT_CONTEXT.md)
- [Historical technical review brief](GROK_REVIEW_BRIEF.md)
- [Review and maintenance rules](AGENTS.md)
- [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md)
- [Release notes v1.0.0](RELEASE_NOTES_v1.0.0.md)
- [MIT License](LICENSE)
- [Russian README](README.ru.md)

The implementation and current workflow are authoritative for actual behavior. Documentation must be updated whenever source behavior changes.
