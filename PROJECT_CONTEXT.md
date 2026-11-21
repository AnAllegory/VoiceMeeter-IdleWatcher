# VoiceMeeter IdleWatcher — Project Context / Handover

**Last reviewed:** 2026-11-20  
**Repository:** AnAllegory/VoiceMeeter-IdleWatcher  
**Default branch:** main  
**Visibility:** Public  
**Purpose:** let the maintainer and a future ChatGPT conversation restore the working context without relying on old chat history.

> IMPORTANT FOR A NEW CHAT: Read this file first, then read the current contents of both source files in the repository. Treat the repository as the source of truth for code. Treat this document as a handover note, not as a substitute for inspecting the current source. Distinguish facts verified in code from behavior reported by the maintainer on the local PC. Do not assume older chat messages describe the latest files.

## 1. Quick resume instructions

When starting a new ChatGPT conversation, the maintainer can provide this repository link:

https://github.com/AnAllegory/VoiceMeeter-IdleWatcher

Suggested instruction:

"Please read PROJECT_CONTEXT.md and inspect the current PS1 and VBS files in this public GitHub repository. Restore the project context from the repository. Before suggesting code changes, compare your understanding with the current source. Work one concrete step at a time and do not assume old chat history is available."

The GitHub connection was confirmed able to read this public repository on 2026-11-18. This does not guarantee that every new chat will automatically inspect it: explicitly ask the assistant to read the context file and current source files. Repository access also depends on the GitHub connection and its repository permissions still being enabled.

## 2. Project purpose

VoiceMeeter IdleWatcher is a Windows PowerShell automation utility. It monitors Windows idle time and the display power state. It sends a VoiceMeeter shutdown command only when the user has been idle for the configured period and the display state is fully Off.

The key safety rule is:

- Display Off (0) + idle threshold reached: automatic VoiceMeeter shutdown is allowed.
- Display On (1): shutdown blocked.
- Display Dimmed (2): shutdown blocked.
- Display state unknown: shutdown blocked.

Stopping IdleWatcher is not the same as shutting down VoiceMeeter. The STOP command stops the automation process; it does not itself close VoiceMeeter.

## 3. Repository contents

Expected project structure:

~~~text
VoiceMeeter-IdleWatcher/
├── VoiceMeeter-IdleWatcher.ps1
├── VoiceMeeter-IdleWatcher.vbs
├── README.md
├── README.ru.md
├── PROJECT_CONTEXT.md
├── AGENTS.md
├── SECURITY.md
├── ARCHITECTURE.md
├── CHANGELOG.md
├── LICENSE
├── RELEASE_NOTES_v1.0.0.md
├── .github/
│   └── workflows/
│       └── powershell-check.yml
└── .gitignore
~~~

The repository is public. Do not add runtime logs, rotated logs, KeePass databases, passwords, tokens, recovery codes, or other secrets.

## 4. Source files and responsibilities

### VoiceMeeter-IdleWatcher.ps1

The main watcher. The current source has 1,572 lines (63,329 bytes in the fetched UTF-8 file). It includes:

- Parameters: Mode (Start or Stop), IdleMinutes (default 8; valid range 1–60), DebugMode switch, and StartupStatusFile.
- Windows idle-time retrieval through GetLastInputInfo.
- Display power-state notifications through PowerSettingRegisterNotification and a callback for the session display status GUID.
- VoiceMeeter Remote API interop through a dynamically initialized C# type and P/Invoke declarations.
- VoiceMeeter Remote API DLL discovery using Windows registry install information and common Program Files folders.
- Single-instance protection using the named mutex Local\VoiceMeeter-IdleWatcher.
- Graceful stop signaling using Local\VoiceMeeter-IdleWatcher.Stop.
- A separate named mutex for log writes.
- Primary, fallback, and emergency log paths.
- API login recovery when Login returns -2: perform Logout, then retry Login.
- VoiceMeeter shutdown through the Remote API parameter Command.Shutdown.
- Optional MacroButtons displayed-state synchronization through VBVMR_MacroButton_SetStatus in STATEONLY mode. The current default is VoiceMeeter Remote API logical button ID 1; the value is configurable in the source and -1 disables synchronization. While active, the watcher asserts ON every 10 seconds and asserts OFF during graceful cleanup. A repeated START request signals the existing process through an auto-reset named event for an immediate ON refresh. No GetStatus readback is used. API or button unavailability is non-fatal and DEBUG-only.
- Revalidation of idle time and display state immediately before dispatching shutdown.
- Follow-up probes to detect whether VoiceMeeter stopped or restarted after a shutdown request.
- A configurable source constant `$ShutdownCommandLimit` (default 3) caps unconfirmed `Command.Shutdown` retries at three successful API calls per engine run. The counter resets only after a confirmed engine stop or a new idle cycle; failed API calls do not count. Once exhausted, one WARN is logged and later suspended retries are DEBUG-only.
- Startup log identifies watcher version 1.0.1. Recovered API login code 1 keeps the connection-warning flag set while the engine is absent; other successful login codes clear it so a genuine connection restoration can be logged.
- Cleanup that logs out of the API, unregisters display notifications, closes the stop event, and releases the watcher mutex.

Current code implements optional MacroButtons displayed-state synchronization with VBVMR_MacroButton_SetStatus in STATEONLY mode. It intentionally does not call VBVMR_MacroButton_GetStatus. Describe the feature as process-state assertion, not button-state comparison.

### VoiceMeeter-IdleWatcher.vbs

The launcher/controller. It:

- Locates the matching PS1 file beside itself using the VBS filename as the base name.
- Starts Windows PowerShell hidden.
- Resolves native 64-bit PowerShell through Sysnative when needed from a 32-bit WScript process on 64-bit Windows.
- Supports default Start behavior and explicit /start or /stop arguments.
- Creates a temporary startup-status path for Start and waits for an explicit startup result.
- Writes startup status tokens through the `Write-StartupStatus` helper.
- Reports early startup errors and a timeout rather than assuming a successful start.
- For Stop, waits for the PowerShell controller to finish and checks its exit status.

Keep the PS1 and VBS files next to each other and keep their base filenames matching.

## 5. Current source configuration

Verified in the current PS1 source:

| Setting | Value | Meaning |
|---|---:|---|
| IdleMinutes | 8 | Default idle threshold; parameter permits 1–60 minutes. |
| CheckIntervalSec | 10 seconds | Main-loop check/wait interval. |
| RetryIntervalSec | 30 seconds | Retry after relevant API errors. |
| WatcherVersion | 1.0.1 | Version recorded in the startup log. |
| ShutdownCommandLimit | 3 | Maximum successful unconfirmed shutdown commands per engine run. |
| EngineAbsentProbeIntervalSec | 3 seconds | Probe interval while VoiceMeeter engine is absent. |
| DisplayNotificationTimeoutSec | 5 seconds | Wait for an initial display-state notification. |
| PostShutdownProbeIntervalSec | 1 second | Prompt probe after shutdown request. |
| PostShutdownRestartProbeIntervalSec | 3 seconds | Probe interval while waiting for possible engine restart. |
| PostShutdownConfirmationTimeoutSec | 5 seconds | Confirmation window before retry logic. |
| ApiSessionRecoveryRetryIntervalSec | 5 seconds | Delay before API session recovery retry. |
| DebugMode | Off by default | Enabled by passing -DebugMode. |
| MacroButtonLogicalIndex | 1 | Default VoiceMeeter Remote API logical button ID to synchronize. Set to -1 to disable; choose an ID that matches the local MacroButtons layout. |
| MacroButtonSyncIntervalSec | 10 seconds | Interval for reasserting the displayed ON state while the watcher process is active. |

Logging limits in the current code:

- Primary log maximum: 500 KB.
- Fallback log maximum: 2 MB.
- Fallback directory: %LOCALAPPDATA%\VoiceMeeter-IdleWatcher.
- Emergency log: %TEMP%\VoiceMeeter-IdleWatcher-emergency.log.
- Primary log is placed beside the PS1 file and uses the script base name plus .log.
- When a log reaches its limit, the existing .old archive is replaced by the newly rotated log.

## 6. VoiceMeeter Remote API and display behavior

- The PS1 dynamically discovers the DLL matching the PowerShell process architecture.
- A 64-bit PowerShell process requires VoicemeeterRemote64.dll.
- A 32-bit PowerShell process requires VoicemeeterRemote.dll.
- API Login return code 1 is treated by the script as a successful API login when the VoiceMeeter engine is not currently running; the watcher then waits for engine startup.
- API Login return code -2 triggers a Logout-before-retry recovery path.
- Shutdown is requested through SetParameterFloat('Command.Shutdown', 1).
- The script rechecks both idle duration and display state immediately before issuing shutdown. The potentially blocking pre-dispatch log write occurs before this final revalidation; no log write occurs between the final check and the API call.
- The code tracks whether the engine stopped after shutdown and whether it restarted during the same idle period.
- An unknown display state is fail-safe and blocks shutdown.

Do not infer which Remote API status indicator (R) in the VoiceMeeter UI belongs to which client without a direct test. The user previously observed that an R indicator went dark when the watcher process exited, but attribution of every R indicator was not independently established.

## 7. VBS entry points

From the project directory:

~~~text
wscript.exe VoiceMeeter-IdleWatcher.vbs
~~~

Starts the watcher hidden. Default mode is Start.

~~~text
wscript.exe VoiceMeeter-IdleWatcher.vbs /start
~~~

Explicit Start.

~~~text
wscript.exe VoiceMeeter-IdleWatcher.vbs /stop
~~~

Requests graceful stop. STOP is expected to make the watcher perform API Logout, release its mutex, and exit.

The VBS launcher and PS1 must remain next to each other with matching base names.

## 8. VoiceMeeter MacroButtons commands

The maintainer confirmed that the following exact commands work in the current local setup.

### START — Button ON

~~~vb
System.Execute("%windir%\System32\cmd.exe","C:\Path\To\VoiceMeeter IdleWatcher","/C wscript.exe VoiceMeeter-IdleWatcher.vbs");
~~~

### STOP — Button OFF

~~~vb
System.Execute("%windir%\System32\cmd.exe","C:\Path\To\VoiceMeeter IdleWatcher","/C wscript.exe VoiceMeeter-IdleWatcher.vbs /stop");
~~~

The working directory is specific to the maintainer's current PC. If the project moves, update the working-directory field. The example path is generic and must be replaced with the actual project directory on each computer.

## 9. Verified behavior reported by the maintainer

The following behavior was reported as successfully observed on the maintainer's PC:

- The exact MacroButtons START and STOP System.Execute commands above work. MacroButtons STATEONLY display synchronization has also been confirmed: the button indicator follows watcher start/stop without executing the button macro.
- A normal graceful stop produced log messages including:
  - Logout succeeded (code 0).
  - Single-instance mutex released successfully.
  - Stop confirmed.
  - Watcher process cleanup sequence has ended.
- Stopping the watcher caused the relevant PowerShell process to exit.
- The user observed a VoiceMeeter Remote API indicator go dark when the watcher exited. Do not generalize this observation to every R indicator without further evidence.

These are user-reported local runtime observations. They are not the same as an independent test performed by ChatGPT.

## 10. Known limitations and open items

1. **MacroButtons visual-state synchronization has been verified on the maintainer's Windows system.** The watcher asserts the configured button state every 10 seconds with Remote API STATEONLY mode; it does not read the button state first. It does not execute the button macro and creates no helper process. The current source default is logical button ID 1; choose an ID that matches the local MacroButtons layout. Repeated START requests signal the existing watcher for an immediate ON refresh.
2. If the configured button or MacroButtons API function is unavailable, synchronization is skipped and retried later. Repeated identical failures are suppressed and recorded only at DEBUG level; they do not stop the watcher.
3. The CI workflow performs syntax and static analyzer checks only. It does not execute the watcher or test actual VoiceMeeter/MacroButtons/display behavior.
4. The project is licensed under the MIT License; see LICENSE.
5. Documentation uses a generic example path and contains no maintainer-specific working-directory path.
6. Long-duration operation and sleep/wake recovery remain under observation on the maintainer's Windows system. GitHub Actions cannot independently verify the local VoiceMeeter engine, MacroButtons UI, or display hardware.

## 11. Logs and troubleshooting

Expected logs:

- Primary: VoiceMeeter-IdleWatcher.log beside the PS1.
- Fallback: %LOCALAPPDATA%\VoiceMeeter-IdleWatcher\VoiceMeeter-IdleWatcher-fallback.log.
- Emergency: %TEMP%\VoiceMeeter-IdleWatcher-emergency.log.

Important messages:

- "Watcher is already running." means a watcher already owns the single-instance mutex; a second Start instance is not created.
- A clean Stop should include successful API Logout and mutex release messages.
- If the initial display state is not received, it remains unknown and automatic shutdown is blocked until a valid notification arrives.
- Do not kill the watcher process as the normal stop method; use the VBS /stop entry point so cleanup can run.

## 12. Working preferences for future assistance

When assisting with this project:

- Use the current files in this repository as the source of truth, not guesses or stale chat summaries.
- Work in Russian unless the maintainer asks otherwise.
- Give one concrete instruction or question at a time.
- Prefer static code inspection of the actual source before proposing changes.
- Do not initiate unrelated registry checks, system diagnostics, or broad troubleshooting when the user asks for source review.
- Do not repeat checks or ask for information already present in this document or in the current source.
- Do not claim code was tested on the user's PC unless the user actually runs it and reports the result.
- Do not change source code or commit changes without the maintainer's explicit request.
- Explain risks plainly and avoid lengthy multi-stage troubleshooting unless it is necessary.
- If a local file is needed but not present in the repository or current conversation, ask the user to provide that exact current file.

## 13. Automated checks

- `.github/workflows/powershell-check.yml` runs on pushes and pull requests targeting `main`, and can also be started manually.
- It explicitly uses the Windows PowerShell Desktop shell on a Windows GitHub-hosted runner.
- It checks required repository files, including `AGENTS.md` and `SECURITY.md`, and parses the main PS1 source using the Windows PowerShell 5.1 parser. Missing required files and parser errors fail the workflow.
- It also invokes `VoiceMeeter-IdleWatcher.vbs` with an intentionally invalid argument through Windows Script Host (`cscript.exe`). The launcher must parse, print the expected argument error, and return exit code 4; this test exits before starting the watcher.
- It installs PSScriptAnalyzer 1.25.0 and reports Error, Warning, and Information findings.
- PSScriptAnalyzer findings with severity **Error** fail the workflow. Warning and Information findings remain visible but non-blocking.
- The current known baseline warning is `PSReviewUnusedParameter` for `StartupStatusFile`. The parameter is used by the nested `Write-StartupStatus` helper; do not remove the startup-status parameter contract merely to silence this analyzer warning.
- The most recent baseline observation before enabling Error-level blocking was GitHub Actions run 48: one Warning and no Error-level findings.
- This is static analysis only. It does not execute the watcher, connect to VoiceMeeter, test MacroButtons, or verify actual display power notifications.

## 14. Change history

- `CHANGELOG.md` records the repository baseline and future notable changes.
- The v1.0.0 GitHub Release was published on 2026-11-19. The `v1.0.0` tag points to commit `44ee9d4f0bd404a4c8d0d4008523010ea2c07a7c`; GitHub Actions run `44515517384` passed on that exact commit. Later documentation corrections on `main` do not change the published tag snapshot.

## 15. Architecture documentation

- `ARCHITECTURE.md` contains a bilingual high-level description and Mermaid diagrams for the watcher’s main control flow, safety checks, and graceful stop path.
- `ROADMAP.md` records potential future improvements, deliberately deferred ideas, and the project’s principles for deciding whether changes are warranted. It is a planning note, not a commitment to implement every item.
- Both README files include a concise overview diagram and link to the detailed architecture document.
- The diagram is intentionally high-level; retry, timeout, API recovery, and logging details remain defined by the current source code.

## 16. Current repository state at handover

At the time this context file is being prepared:

- Repository: AnAllegory/VoiceMeeter-IdleWatcher.
- Visibility: Public.
- Default branch: main.
- The repository contains the current PS1 and VBS source files, bilingual README files, project handover notes, architecture documentation, changelog, and automated PowerShell checks.
- GitHub connector read access to the public repository was successfully used in the current conversation.
- README.md and README.ru.md contain the English and Russian project documentation, including the main Mermaid flow diagram.
- PROJECT_CONTEXT.md is the handover document for restoring project context in a future chat.
- ARCHITECTURE.md contains the bilingual detailed architecture overview and Mermaid diagrams.
- The current source files were fetched back from GitHub for this review: PS1 is 1,572 lines / 63,329 bytes; VBS is 187 lines / 7,109 bytes (UTF-8 content returned by GitHub).
- MacroButtons visual-state synchronization is implemented with STATEONLY, a 10-second ON assertion interval, and an immediate refresh event for duplicate START requests. The current source default logical ID is 1 and can be changed to match a local MacroButtons layout. The maintainer confirmed the visual state follows watcher start/stop without executing the button macro.
- The current PS1 and VBS sources contain no maintainer-specific working-directory path, and no obvious API-token pattern was detected in a basic static scan. Documentation examples use a generic path. This is not a comprehensive security audit.
- The repository is public. Do not commit runtime logs, credentials, recovery codes, local database files, or other private information.

