# VoiceMeeter IdleWatcher — Project Context / Handover

**Last reviewed:** 2026-11-24  
**Current repository:** AnAllegory/VoiceMeeter-IdleWatcher  
**Default branch:** main  
**Visibility:** Public  
**Source baseline:** v1.0.5 published stable; v1.0.6 candidate under review on a separate branch  
**Status:** `main` remains at the v1.0.5 published stable baseline. The v1.0.6 maintenance candidate is prepared on separate branch `prepare-v1.0.6-maintenance` and is under review in [PR #13](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/pull/13); it is not yet merged, tagged or published. Tag `v1.0.5` points to validated commit `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`; the release discussion is [#11](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/discussions/11).

> For a new review or development session: read this document, REPOSITORY_LINEAGE.md, ARCHITECTURE.md, CHANGELOG.md, ROADMAP.md, SECURITY.md and AGENTS.md, then inspect the actual source files and the public modular workflow. The current source is authoritative if documentation and code ever disagree.

## 1. Repository relationship and lineage

There is one canonical public repository:

- Public project: https://github.com/AnAllegory/VoiceMeeter-IdleWatcher
- Historical private modular workspace: https://github.com/AnAllegory/VoiceMeeter-IdleWatcher-Beta

The public repository's main branch previously contained the monolithic v1.0.1 source line. The modular implementation was developed in the private workspace through internal milestones v1.0.2, v1.0.3, v1.0.4 and v1.0.5.

The modular source baseline v1.0.5 was merged into public main through PR #10 (merge commit `5436b1ccbbd464aa43a4846af53750fafbf126e5`). The merge preserved the original public repository's commit history. The private Beta repository remains a historical workspace and is not the canonical source for future public development.

The repositories do not have asserted direct Git parent/child ancestry. The public v1.0.0 and v1.0.1 tags remain unchanged historical releases. The modular v1.0.5 baseline was integrated through PR #10 and published as the latest stable public release on 2026-11-22. The `v1.0.5` tag points to validated `main` commit `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`. The v1.0.2-v1.0.4 numbers remain internal development milestones, not separate public tags. The release includes bilingual notes and a linked Announcements discussion (#11).

The former public monolithic CI workflow was replaced with the modular workflow. Do not restore the old workflow unchanged: it validates a different source layout.

See REPOSITORY_LINEAGE.md for the timeline, module mapping and release boundary.

## 2. Purpose and non-negotiable safety rule

VoiceMeeter IdleWatcher is a Windows PowerShell automation utility. It monitors Windows idle time and display power state, and requests VoiceMeeter shutdown only when the configured idle threshold has elapsed and the display is fully Off.

Automatic shutdown requires:
- Idle threshold reached.
- Display fully Off (0).
- No pending graceful /stop request at final validation.

Display On (1), Dimmed (2), unknown or unavailable blocks automatic shutdown. After a successful pre-shutdown MacroButtons OFF write and its 1000ms allowance, all final safety conditions are rechecked immediately before Command.Shutdown.

Stopping IdleWatcher is not the same as shutting down VoiceMeeter. A normal /stop request terminates the watcher and performs cleanup; it does not itself send Command.Shutdown.

## 3. Current source files and responsibilities

- VoiceMeeter-IdleWatcher.ps1 — orchestrator, configuration loading/validation, monitoring loop, engine/API state, shutdown flow and retry policy.
- VoiceMeeter-IdleWatcher.psd1 — runtime configuration.
- VoiceMeeter-IdleWatcher.vbs — hidden launcher, explicit startup-status handling and graceful /stop.
- VoiceMeeter-IdleWatcher.Support.psm1 — logging, startup-status writing, stop signaling and immediate refresh signaling.
- VoiceMeeter-IdleWatcher.Interop.psm1 — Remote DLL discovery, C# marker replacement/compilation, API Login and session recovery.
- VoiceMeeter-IdleWatcher.MacroButtons.psm1 — single STATEONLY write path and last-write status.
- VMRIdleWatcherNative.cs — Windows idle/display/event interop and VoiceMeeter Remote API declarations.

Import order: **Support -> Interop -> MacroButtons**.

Keep the PS1, PSD1, VBS, three modules and C# source together in one application folder. Preserve tabs for code indentation.

## 4. Configuration baseline

Values verified in the current PSD1/source:

| Setting | Default | Meaning |
|---|---:|---|
| IdleMinutes | 8 | Idle threshold; valid range 1–60 |
| DebugMode | false | Detailed per-probe/per-write and loop diagnostics |
| ShutdownCommandLimit | 3 | Bounded successful, unconfirmed Shutdown commands per engine run |
| CheckIntervalSec | 10 | Main monitoring interval |
| RetryIntervalSec | 30 | Retry interval after relevant API errors |
| EngineAbsentProbeIntervalSec | 3 | Probe interval while engine is absent |
| DisplayNotificationTimeoutSec | 5 | Initial display-notification timeout |
| PostShutdownProbeIntervalSec | 1 | Prompt probe after Shutdown |
| PostShutdownRestartProbeIntervalSec | 3 | Probe interval while waiting for restart |
| PostShutdownConfirmationTimeoutSec | 5 | Stop confirmation window |
| ApiSessionRecoveryRetryIntervalSec | 5 | API session recovery interval |
| StopWaitTimeoutSec | 20 | Graceful stop wait |
| MacroButtonLogicalIndex | 1 | Remote API logical button index; -1 disables it |
| MacroButtonSyncIntervalSec | 10 | Periodic indicator write interval |
| MaxLogSizeBytes | 512000 | Primary log size threshold |
| FallbackMaxLogSizeBytes | 2097152 | Fallback log size threshold |

Numeric and named configuration values are bounded and validated at startup. STATEONLY mode is not a PSD1 setting. Keep `DebugMode = false` for normal operation; `true` enables high-volume diagnostic traces and can trigger log rotation quickly. The default primary and fallback log thresholds are 500 KB and 2 MB.

## 5. Critical implementation contracts

### PowerShell and module structure

- Windows PowerShell 5.1 compatibility is mandatory. Do not introduce PowerShell 7-only syntax or dependencies.
- Keep import order Support -> Interop -> MacroButtons.
- Keep code indentation tabs, not spaces.
- Keep the C# path marker __VOICEMEETER_DLL_PATH__ exactly once inside the verbatim string in VMRIdleWatcherNative.cs.
- Interop reads that C# file as UTF-8, doubles embedded quotes in the selected DLL path and replaces the marker before compiling.
- Select VoicemeeterRemote64.dll or VoicemeeterRemote.dll according to the PowerShell watcher process architecture, not guessed VoiceMeeter process bitness.
- Preserve the existing VBS launcher contract, startup status, single-instance mutex, named events, display notifications, API recovery, retry limits and cleanup paths.

### MacroButtons

- One centralized writer only: Invoke-MacroButtonStateSync.
- STATEONLY is fixed to 0x00000002 inside VoiceMeeter-IdleWatcher.MacroButtons.psm1.
- No GetStatus readback and no MacroButton_IsDirty call.
- Logical ID defaults to 1; -1 disables this optional feature.
- Synchronization errors remain non-fatal.
- API return code 0 means the write was accepted; it is not a UI readback.
- Desired, LastAccepted, WriterStatus and LastAcceptedAt are distinct. WriterStatus is the last writer result/status, not live API health. LastAccepted is not proof of the current visible button state.

### API availability gate (introduced in v1.0.5; retained in v1.0.6)

Periodic and manual-refresh writes require both a known API state and a confirmed running VoiceMeeter engine. A known-stopped state (IsParametersDirty = -2) means the server is unavailable, not that an OFF write can be sent. In this state, no repeated write is attempted and the last API-accepted indicator state is retained.

At startup or recovery, a Login result that indicates there is no running engine does not cause an initial OFF write. When the engine later becomes available, the watcher asserts ON.

### Automatic shutdown sequence (v1.0.4, retained in v1.0.6)

1. Check idle threshold, display Off and no pending /stop.
2. Attempt STATEONLY OFF while the API is available.
3. If OFF is accepted, wait 1000ms for the MacroButtons application to process its display-state polling notification.
4. Repeat idle, display and /stop checks immediately before Command.Shutdown.
5. If validation fails, cancel Shutdown and restore ON when possible.

The wait is not a readback. If MacroButtons is disabled or the optional OFF write fails, the wait is skipped and MacroButtons remains non-fatal. The final safety validation is still mandatory.

## 6. Maintainer-reported runtime evidence

The following are observations reported by the maintainer from the target Windows PC. They are not tests executed by GitHub Actions or by an external reviewer.

### Earlier evidence and the reason for v1.0.4

A prior v1.0.3 automatic-shutdown log recorded STATEONLY OFF accepted at 14:47:51.073 and Shutdown sent at 14:47:51.098, only 25ms later. The maintainer reported that the visible indicator had not extinguished before VoiceMeeter closed. This supported a timing-race hypothesis and led to the v1.0.4 1000ms allowance. The exact UI scheduling was not measured.

### v1.0.4 evidence and the reason for v1.0.5

The v1.0.4 log showed:
- 15:39:19.644 — OFF accepted.
- 15:39:19.651 — 1000ms allowance started.
- 15:39:20.669 — final safety validation passed.
- 15:39:20.687 — Shutdown returned code 0.
- 15:39:21.741 — engine stop confirmed.
- 15:39:30.801 — a redundant OFF write was attempted after the API had returned -2.

The last item led to the v1.0.5 write gate.

### v1.0.5 API transition and automatic shutdown test (2026-11-22)

The maintainer's v1.0.5 log recorded an engine/API availability transition:
- 16:00:38.322 — Remote API available.
- 16:00:38.327 — engine availability confirmed.
- 16:00:38.410 — MacroButton 1 ON accepted.
- 16:01:28.554 — API reported no server (-2); the watcher logged that OFF could not be sent and the last accepted state was retained.
- 16:01:42 — graceful watcher cleanup completed and the single-instance mutex was released.

A subsequent automatic-shutdown cycle recorded:
- 16:09:13 — display fully Off.
- 16:14:13.513 — idle threshold reached and MacroButton 1 OFF accepted.
- 16:14:13.519 — 1000ms refresh allowance started.
- 16:14:14.537 — final idle/display/stop validation passed.
- 16:14:14.557 — Command.Shutdown returned code 0.
- 16:14:15.617 — engine stop was confirmed.
- 16:14:24.642 — Remote API reported no server.
- 16:16:38.743 — user activity detected.
- 16:16:48.773 — display reported On.

After waking the PC, the maintainer visually confirmed that MacroButton 1 was not lit and VoiceMeeter was not running.

**What this proves:** the OFF write was accepted before Shutdown; the 1000ms wait and final revalidation occurred in the logged order; Shutdown succeeded; the engine stopped; and the indicator was OFF after the PC was awake again.

**What it does not prove:** the exact visual instant when the MacroButtons window extinguished the button relative to engine shutdown. The maintainer could not observe the button while the display was Off. There is no API readback in this design.

### v1.0.6 maintenance candidate (prepared 2026-11-24; not published)

The separate-branch v1.0.6 candidate contains two maintenance changes:

- The periodic status snapshot is emitted on the first main-loop pass, then only when at least 300 seconds have elapsed since the previous snapshot. The main monitoring loop remains at its configured interval (10 seconds by default); the MacroButtons synchronization interval is separate and unchanged.
- The diagnostic `Desired` summary now reports OFF only when the watcher has an accepted OFF write pending its own shutdown. If VoiceMeeter is confirmed stopped and no pre-shutdown OFF was accepted, the snapshot reports that writes are paused and the last accepted API state is retained. The writer, API gates and shutdown decision path are unchanged.

The candidate has not yet received target-PC runtime verification. Before publication, the maintainer should confirm the immediate first snapshot, the minimum 300-second interval, and one normal idle-plus-display-Off shutdown cycle. Additional review scenarios remain observations to test, not confirmed defects: Sleep/Wake event ordering, /stop arriving after Shutdown dispatch while the Remote API is still responding, and VoiceMeeter starting when the idle threshold is already reached and the display is Off.

## 7. Accepted limitations and scope decisions

### Manual VoiceMeeter Exit

When VoiceMeeter is closed manually, the API server may disappear before the watcher can deliver STATEONLY OFF. After IsParametersDirty = -2, the watcher cannot send a command through that absent server. v1.0.5 now avoids futile writes and retains the last accepted indicator state. When VoiceMeeter becomes available again, the watcher asserts ON.

This is an accepted API lifecycle limitation, not a reason to add an independent writer.

### Deliberately not implemented

- VoiceMeeter process polling or WMI process monitoring.
- Process.Exited subscriptions as a way to write after API teardown.
- A second MacroButtons writer.
- GetStatus or MacroButton_IsDirty readback/polling in the watcher.
- A configurable STATEONLY bitmode.
- DLL selection based on guessed VoiceMeeter process bitness.

Any proposal to revisit these decisions must identify a reproducible problem and preserve the single-writer/API-availability model unless the maintainer explicitly approves a new design.

## 8. CI and validation

The public modular workflow is .github/workflows/powershell-check.yml. It runs on pushes to main and pull requests targeting main. See the public repository's [Actions page](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/actions) for the latest main-branch validation result.

The workflow performs:
- Windows PowerShell 5.1 parsing for the main script and PowerShell modules.
- Static project-contract checks for the v1.0.6 candidate version, the 1000ms sequence, final safety validation, the STATEONLY invariant, no-readback contract, API write gates, diagnostic-summary semantics and 300-second status-snapshot cadence.
- Tab-indentation checks for source files.
- C# interop compilation after the DLL marker is replaced with a placeholder path.
- VBS invalid-argument validation without launching the watcher.
- PSScriptAnalyzer 1.25.0 on the main script and PowerShell modules; Error-level findings fail CI, while Warning and Information findings are reported but non-blocking.

It does **not** launch the watcher, connect to a real VoiceMeeter instance, exercise Remote API sessions or test the visible MacroButtons UI/display hardware.

Always distinguish static CI, source inspection and maintainer-reported runtime behavior.

## 9. Documentation map

- README.md and README.ru.md — user-facing overview, requirements, configuration and start/stop instructions.
- REPOSITORY_LINEAGE.md — history of the public monolithic source and its modular development workspace.
- ARCHITECTURE.md — module boundaries, state flow and safety contracts.
- CHANGELOG.md — public change history, v1.0.5 release record and v1.0.6 candidate changes.
- PROJECT_CONTEXT.md — this handover, source invariants and runtime evidence.
- GROK_REVIEW_BRIEF.md — historical technical review request and its disposition.
- AGENTS.md — mandatory rules for future review and maintenance.
- ROADMAP.md — current project status, follow-up observations and deliberate non-goals.
- SECURITY.md — vulnerability reporting guidance and safe handling of diagnostic material.
- CONTRIBUTING.md and CONTRIBUTING.ru.md — contributor workflow, development requirements and project safety contracts.
- .github/ISSUE_TEMPLATE/ and .github/PULL_REQUEST_TEMPLATE.md — structured issue and pull-request forms.
- RELEASE_NOTES_v1.0.5.md — published stable-release description and verification notes.
- RELEASE_NOTES_v1.0.6.md — prepared maintenance-candidate description and pre-publication runtime checklist.
- LICENSE — MIT license terms.

This repository is the canonical documentation and source location. Keep the bilingual guides and project records synchronized with implementation changes.

## 10. Working rules for future assistance

- Communicate in Russian unless the maintainer asks otherwise.
- Use the actual current source files and workflow as the implementation truth.
- Treat public main as the canonical source baseline. Review proposed changes through pull requests before merging; use the private Beta repository only as historical lineage context.
- Give one concrete user instruction at a time.
- Do not ask for information already recorded in this handover or supplied in the current conversation.
- Do not claim a runtime test was executed by the assistant. Attribute local test results to the maintainer.
- Keep documentation consistent in English and Russian where both versions exist.
- Do not create or move public tags, or publish releases, unless the maintainer explicitly authorizes the release action.
