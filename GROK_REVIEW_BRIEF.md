> **Current disposition (2026-11-22):** This is a retained historical architecture-review brief, not an open request to add process monitoring. The original manual-Exit question was resolved without a process monitor, WMI subscription, launcher ownership model or second writer. The modular v1.0.5 source baseline is now integrated into the public repository. Its latest maintainer-reported runtime test confirmed the automatic shutdown sequence and the indicator's OFF state after the PC was awakened; the exact visual instant before engine shutdown remains unobserved. See PROJECT_CONTEXT.md and CHANGELOG.md.

# Historical technical review: Manual VoiceMeeter Exit and MacroButtons STATEONLY indicator

## Why this brief is retained

This file records the original review question and the design constraints that shaped the modular Beta. Keep it as review history. Do not treat its original no-edit request as a current task instruction; current scope and authorization come from the maintainer's latest request and AGENTS.md.

## Repository and source context

- Canonical public repository: [AnAllegory/VoiceMeeter-IdleWatcher](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher), now containing the modular source baseline v1.0.5.
- Historical private development workspace: [AnAllegory/VoiceMeeter-IdleWatcher-Beta](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher-Beta), where the modular milestones v1.0.2-v1.0.5 were developed.
- The two repositories do not have asserted direct Git ancestry; the modular files were integrated while preserving the public repository's prior history.
- The current source detects engine/API state through VMRIdleWatcherNative.IsParametersDirty(). It does not enumerate VoiceMeeter processes.
- DLL selection follows the PowerShell watcher process architecture.
- MacroButtons uses one VBVMR_MacroButton_SetStatus writer with STATEONLY (0x00000002). No GetStatus readback is used.

## Original review objective

Determine whether the MacroButtons indicator can reliably become OFF when VoiceMeeter is closed manually through its Exit menu, and return to ON when VoiceMeeter becomes available, without breaking periodic synchronization or the automatic-shutdown path.

The original review asked for documented API mechanisms, possible Windows process-lifecycle mechanisms, architecture alternatives, race/cleanup analysis and a practical test matrix. Its central constraint was not to claim that a process-exit event can send an API command after the API server has already disappeared.

## Original research topics

### A. VoiceMeeter Remote API

- Determine whether a documented pre-exit notification or lifecycle hook exists for ordinary GUI Exit.
- Establish whether VBVMR_MacroButton_SetStatus can be accepted after the Remote API server has disappeared.
- Distinguish Login success, engine availability, Logout and button-write acceptance from displayed-state readback.

### B. Windows process lifecycle

Potential mechanisms considered:
- System.Diagnostics.Process / Process.Exited;
- WMI Win32_ProcessStartTrace and Win32_ProcessStopTrace;
- periodic process polling;
- a supported pre-exit notification, if one exists.

The key distinction is notification timing: a normal process-exited event arrives after process termination. It cannot by itself make an already unavailable Remote API accept a STATEONLY command.

### C. Architecture options

The original review compared:
1. Remote API as the only authority for engine state, with process monitoring at most for diagnostics.
2. Process state as an additional signal while retaining API readiness as the gate for all writes.
3. A documented pre-exit interception/notification approach, if supported.
4. Launcher/ownership management, with its usability trade-offs.

### D. Required behavior to preserve

- Final idle/display/STOP validation before Command.Shutdown.
- STATEONLY only; no button macro execution.
- No button-state readback.
- One centralized writer.
- MacroButtons optional and non-fatal.
- Windows PowerShell 5.1 compatibility.
- DLL selection by watcher process architecture.
- Graceful /stop, API recovery and resource cleanup.

## Review disposition applied during modular development

The resulting implementation deliberately did **not** add process monitoring, WMI subscriptions, Process.Exited, launcher ownership or another MacroButtons writer.

Manual VoiceMeeter Exit remains an accepted API lifecycle limitation. Once IsParametersDirty = -2 confirms the Remote API server is gone, the watcher cannot deliver STATEONLY OFF through that server. The v1.0.5 correction made the watcher skip periodic and manual-refresh writes after confirmed teardown and retain the last API-accepted indicator state. When the engine becomes available again, ON is asserted.

The automatic-shutdown display-refresh issue was separate from manual Exit:
- An earlier test showed OFF accepted only 25ms before Shutdown, while the visible button remained lit.
- v1.0.4 introduced a 1000ms allowance after successful OFF, followed by final safety revalidation.
- v1.0.5 retained that sequence and fixed the no-server write gate.

## Latest v1.0.5 maintainer-reported test (2026-11-22)

The automatic-shutdown log showed:
- 16:14:13.513 — STATEONLY OFF for button 1 accepted.
- 16:14:13.519 — 1000ms allowance began.
- 16:14:14.537 — final idle/display/stop validation passed.
- 16:14:14.557 — Command.Shutdown returned code 0.
- 16:14:15.617 — engine stop confirmed.
- 16:14:24.642 — API reported no server.
- After waking the PC, the maintainer reported that button 1 was not lit and VoiceMeeter was not running.

This confirms the post-wake indicator state and the automatic shutdown sequence. It does not confirm the exact GUI refresh instant before engine shutdown, because the display was Off during that interval. The writer intentionally has no UI readback.

## Review conclusion

The integrated v1.0.5 design remains intentionally conservative:

- Keep the Remote API as the only authority for MacroButtons writes.
- Keep the single STATEONLY writer and no-readback rule.
- Keep the 1000ms pre-shutdown allowance and final safety revalidation.
- Keep no-server write gating and last-accepted-state retention.
- Do not add process monitoring or another writer without a reproducible requirement and a new explicit design decision.

For current status and exact evidence boundaries, use PROJECT_CONTEXT.md and CHANGELOG.md. For implementation details, use ARCHITECTURE.md and the source files.
