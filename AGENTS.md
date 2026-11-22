# Review and maintenance instructions

These instructions apply to the canonical public repository. REPOSITORY_LINEAGE.md records the historical modular-development workspace and the transition into this repository.

## 1. Mandatory reading

Before reviewing or modifying implementation:

1. Read PROJECT_CONTEXT.md for the current baseline, maintainer-reported tests and accepted limitations.
2. Read REPOSITORY_LINEAGE.md for the project's source history and integration decisions.
3. Read ARCHITECTURE.md for module ownership and safety flow.
4. Read CHANGELOG.md for the sequence and rationale of earlier changes.
5. Read the relevant README and GROK_REVIEW_BRIEF.md when the proposed change affects user-facing behavior or the historical review decision.
6. Read ROADMAP.md before proposing new features or architectural additions.
7. Read SECURITY.md before handling or requesting vulnerability details.
8. Inspect all directly related source files and .github/workflows/powershell-check.yml. Source and workflow are authoritative if documentation differs.

## 2. Repository boundaries

- Canonical repository: AnAllegory/VoiceMeeter-IdleWatcher, branch main, current modular source baseline v1.0.5.
- The private AnAllegory/VoiceMeeter-IdleWatcher-Beta repository is retained as a historical development workspace; it is not the canonical source.
- The modular source baseline v1.0.5 is integrated on `main` and prepared as the next public release. The v1.0.2-v1.0.4 numbers remain internal development milestones, not separate public releases.
- Preserve the public repository's existing history, tags and releases. Do not create or move tags or publish releases unless the maintainer explicitly authorizes the publication action.
- Keep the current workflow aligned with the modular source tree; the former monolithic workflow has been replaced.

## 3. Change authorization and discipline

- A request to update documentation authorizes documentation changes, not unrelated implementation changes.
- Do not change implementation, create branches, publish releases or change repository settings unless the maintainer explicitly authorizes the relevant action.
- Prefer one coherent, reviewable change set. When several documents describe the same behavior, update them together.
- Keep English and Russian user-facing documents aligned.
- Do not change version numbers merely because documentation changes.
- Never commit runtime logs, local paths, credentials, API tokens, recovery codes, private databases or other user-specific data.

## 4. Non-negotiable implementation invariants

### Automatic shutdown

- Shutdown is allowed only after the configured idle threshold is reached and the display is fully Off (0).
- On (1), Dimmed (2), unknown or unavailable display state blocks automatic shutdown.
- A graceful /stop request also blocks dispatch.
- Preserve final idle/display/STOP validation immediately before Command.Shutdown.
- In the current v1.0.5 path, successful pre-shutdown STATEONLY OFF is followed by a 1000ms allowance and then final safety validation. If validation fails, Shutdown is cancelled and ON is restored when possible.
- Stopping the watcher is not the same as shutting down VoiceMeeter.

### Remote API and MacroButtons

- Windows PowerShell 5.1 is mandatory; do not add PowerShell 7-only syntax/dependencies.
- MacroButtons remains optional and non-fatal.
- Preserve one writer: Invoke-MacroButtonStateSync.
- Preserve STATEONLY (0x00000002) as a hardcoded module invariant, not a PSD1 option.
- Do not add GetStatus readback or a MacroButton_IsDirty call.
- Default logical button index is 1; -1 disables synchronization.
- Periodic and manual-refresh writes require both known API state and a confirmed running VoiceMeeter engine.
- After IsParametersDirty = -2 confirms server teardown, do not attempt another write; retain the last API-accepted state.
- A successful SetStatus result means API command acceptance, not confirmation that the UI visibly changed.
- WriterStatus is a last-writer result/status, not current API health.
- On graceful watcher stop, assert ON only when the API confirms that VoiceMeeter is available; otherwise retain the last accepted state.

### Interop and lifecycle

- Select the Remote API DLL according to the PowerShell watcher process bitness.
- Preserve the single __VOICEMEETER_DLL_PATH__ marker inside the C# verbatim string and the UTF-8/quote-escaping replacement contract.
- Preserve module import order: Support -> Interop -> MacroButtons.
- Preserve single-instance protection, named stop/refresh events, display notifications, API recovery, retry bounds and resource cleanup.
- Preserve tab indentation in source files.

## 5. Review and evidence standard

Separate the following categories clearly:

1. **Source fact:** directly established by the current implementation.
2. **Documented API fact:** supported by official API/SDK documentation.
3. **Static CI result:** parser, contract and compile checks only.
4. **Maintainer-reported runtime observation:** behavior the maintainer says was seen on their PC.
5. **Hypothesis or open question:** plausible explanation not directly measured.

Do not state that a SetStatus return code proves the visible MacroButtons state. Do not claim that the exact pre-shutdown visual instant was observed in the 2026-11-22 test; only the OFF state after waking the PC was visually confirmed.

For findings, identify the file and function/section, trigger, impact, evidence and focused remedy. Do not turn an intentional limitation into a defect without evidence.

## 6. CI and runtime testing

Inspect .github/workflows/powershell-check.yml before changing CI.

The public workflow checks Windows PowerShell 5.1 parsing for the main PS1, PSD1 and modules; project contracts (including v1.0.5 write gates and the 1000ms shutdown sequence); tab indentation; C# compilation using a placeholder DLL path; the no-log gap between final safety checks and shutdown dispatch; required project documents; the VBS invalid-argument path without starting the watcher; and PSScriptAnalyzer 1.25.0 across the main script and PowerShell modules, with Error-level findings blocking and Warning/Information findings non-blocking. It does not run VoiceMeeter, connect to a real Remote API server or verify MacroButtons UI/display hardware.

Never describe CI as an end-to-end runtime test. Never claim a local runtime test was executed by the assistant; attribute the 2026-11-22 runtime evidence to the maintainer.

## 7. Deliberate scope decisions

Do not add these without a new, explicit design decision and a demonstrated need:

- VoiceMeeter process polling, WMI subscriptions or Process.Exited handlers.
- A second MacroButtons writer or helper process.
- GetStatus readback or MacroButton_IsDirty polling.
- A configurable STATEONLY mode.
- DLL selection based on presumed VoiceMeeter process bitness.
- A weakened or skipped final shutdown-safety check.

Reliability and safe shutdown behavior take precedence over style-only refactoring.
