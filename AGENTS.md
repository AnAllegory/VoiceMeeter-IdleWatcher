# AGENTS.md — Repository Instructions

These instructions apply to the entire VoiceMeeter IdleWatcher repository.

## 1. Project overview

VoiceMeeter IdleWatcher is a Windows PowerShell automation utility. It monitors Windows idle time and display power state, and requests VoiceMeeter shutdown only when the configured idle threshold has elapsed and the display is fully off.

Main implementation files:
- `VoiceMeeter-IdleWatcher.ps1`: watcher, Windows API integration, logging, and VoiceMeeter Remote API integration.
- `VoiceMeeter-IdleWatcher.vbs`: hidden launcher and graceful-stop controller.

## 2. Read before reviewing or changing code

Before making recommendations or modifying implementation:
1. Read `PROJECT_CONTEXT.md` for the maintainer handover, current configuration, verified behavior, and known limitations.
2. Read `ARCHITECTURE.md` for the documented control flow and safety model.
3. Inspect the current PS1 and VBS files. The checked-in source is authoritative for actual implementation behavior.
4. Inspect the relevant README, changelog, and `.github/workflows/powershell-check.yml` when the change affects documentation, releases, or CI.

Do not assume that a handover note or earlier conversation is newer than the current source. When documentation and source disagree, report the discrepancy and treat the current source as the implementation truth.

## 3. Critical safety invariants

These requirements are central to the project and must not be weakened.

### Automatic VoiceMeeter shutdown

A shutdown request is permitted only when both conditions are true at the final check immediately before dispatch:
- The configured Windows idle threshold has been reached.
- The display power state is fully Off (0).

The following display states must block automatic shutdown:
- On (1)
- Dimmed (2)
- Unknown, unavailable, or not yet established

Both conditions must be revalidated immediately before the shutdown command. Do not introduce a path that bypasses this final validation.

Stopping IdleWatcher is not the same as shutting down VoiceMeeter. A normal STOP request must stop the watcher and perform cleanup; it must not itself shut down VoiceMeeter.

### Engine availability and retries

If the VoiceMeeter engine is absent, the watcher must be able to continue monitoring and detect a later engine start. Preserve the existing API recovery, engine-state probing, shutdown confirmation, and retry-limit behavior. Do not increase or bypass the configured shutdown-command limit without an explicit requirement.

## 4. Compatibility and architecture

### Windows PowerShell

- Preserve compatibility with Windows PowerShell 5.1.
- Do not introduce PowerShell 7-only syntax, APIs, or dependencies.
- Preserve the existing parameter interface unless a requested change explicitly requires modifying it.
- Preserve single-instance protection and graceful stop signaling.
- Handle Windows API interop, callbacks, handles, events, mutexes, and notification registrations carefully.
- Ensure acquired resources are released on normal exit and error paths.

### VBS launcher

Preserve the launcher's established contract:
- Start PowerShell hidden.
- Keep the PS1 and VBS files together with matching base filenames.
- Preserve correct native 64-bit PowerShell resolution when required.
- Preserve explicit startup-status reporting, timeout/error handling, and exit-status checks.
- Preserve graceful `/stop` behavior.

### VoiceMeeter Remote API

- Preserve discovery and loading of the DLL that matches the PowerShell process architecture.
- Preserve the existing API login, logout, and session-recovery behavior.
- Do not assume that a successful API login necessarily means that the VoiceMeeter engine is running.
- Do not infer undocumented meanings of Remote API UI indicators without direct evidence.

### MacroButtons synchronization

The project optionally synchronizes a MacroButtons button's displayed state through `VBVMR_MacroButton_SetStatus` in `STATEONLY` mode.

Preserve these documented semantics:
- `STATEONLY` changes the displayed state without executing the button macro.
- The watcher periodically asserts ON while running and asserts OFF during graceful cleanup.
- The current default logical button ID is 1; `-1` disables synchronization.
- A repeated START request can signal the running watcher for an immediate refresh through the existing event mechanism.
- Synchronization is optional and its failures must remain non-fatal.
- Do not describe this as reading or comparing the actual MacroButtons state. The watcher asserts its own process state; it does not use `VBVMR_MacroButton_GetStatus`.

Do not add helper processes or make the main monitoring loop dependent on this optional feature.

## 5. Logging, privacy, and cleanup

Preserve the existing primary, fallback, and emergency logging design, rotation limits, and synchronization for concurrent log writes.

Review changes for:
- Correct mutex and event-handle lifecycle.
- Display-notification unregistration.
- VoiceMeeter Remote API logout.
- Reliable cleanup after startup failures and runtime exceptions.
- Accidental logging of sensitive information.

Never commit runtime logs, rotated logs, temporary files, local backups, KeePass databases, credentials, API tokens, recovery codes, or other private data. Do not add maintainer-specific absolute paths to public source or documentation.

## 6. Code review priorities

Prioritize actionable defects in this order:
1. A safety regression that could cause an unintended VoiceMeeter shutdown.
2. Incorrect or unsafe handling of display power states or idle-time revalidation.
3. Race conditions involving START, STOP, or multiple watcher instances.
4. Remote API session, engine detection, recovery, or retry-limit defects.
5. Resource leaks or incomplete cleanup.
6. Windows PowerShell 5.1 incompatibility.
7. Windows API interop, callback, handle, or process-architecture errors.
8. VBS startup, status reporting, or graceful-stop regressions.
9. Logging, privacy, and security problems.
10. Regressions in optional MacroButtons synchronization.

For each finding:
- Identify the file and precise affected line or code location.
- Describe a concrete trigger or failure scenario.
- Explain the practical impact.
- Suggest a focused correction.
- Use a severity level justified by the demonstrated impact.

Do not present speculation as a confirmed defect. Do not flag documented, intentional behavior as a bug without evidence. Avoid style-only comments unless they create a real maintenance or correctness risk.

## 7. Testing and CI

Inspect `.github/workflows/powershell-check.yml` before changing CI behavior.

The workflow checks required repository files (including `AGENTS.md`, `SECURITY.md`, and `ROADMAP.md`), parses the main PS1 source with the Windows PowerShell 5.1 parser, validates the VBS launcher's invalid-argument path through `cscript.exe` without starting the watcher, checks the MacroButtons STATEONLY/no-readback contract, verifies that final idle/display revalidation immediately precedes `Command.Shutdown` without an intervening log write, and compiles the embedded Remote API interop C# source. PSScriptAnalyzer findings at severity **Error** fail the workflow; Warning and Information findings remain visible but non-blocking. The workflow is static verification; it does not execute the watcher against the maintainer's VoiceMeeter installation or verify real MacroButtons UI and display hardware behavior.

Clearly distinguish:
- Static inspection or CI results.
- Tests actually executed in an appropriate Windows runtime.
- Behavior reported by the maintainer from their own computer.

Never claim that runtime behavior was tested on the maintainer's PC unless the maintainer actually performed that test and reported the result. Do not weaken existing CI checks merely to make a workflow pass.

## 8. Change discipline

- Prefer small, targeted changes that preserve established behavior.
- Inspect the existing implementation before proposing a replacement.
- Avoid unnecessary rewrites, new dependencies, or unrelated features.
- Preserve public interfaces unless a change is requested and its impact is understood.
- Update English and Russian documentation when user-visible behavior or configuration changes.
- Keep documentation consistent with source and CI.
- Do not change code, create commits, or publish releases unless explicitly requested by the maintainer.
- If evidence is insufficient, explain what is unknown rather than guessing.

## 9. Collaboration

- Communicate with the maintainer in Russian unless asked otherwise.
- Give clear, concrete instructions and proceed one logical step at a time.
- Do not repeat checks or request information already available in the repository.
- Explain risks plainly and distinguish confirmed facts from assumptions.
- Treat the repository's current source and the maintainer's explicit requirements as the primary project context.

## 10. Review standard

Reliability, safe shutdown behavior, compatibility, and predictable cleanup take precedence over shortening or beautifying code.

A change is not an improvement if it weakens a safety invariant, recovery path, compatibility guarantee, or graceful-stop behavior. When uncertain, preserve the existing safe behavior and report the uncertainty.
