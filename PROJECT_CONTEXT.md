# VoiceMeeter IdleWatcher — Project Context / Handover

**Last reviewed:** 2026-11-18  
**Repository:** AnAllegory/VoiceMeeter-IdleWatcher  
**Default branch:** main  
**Visibility:** Private  
**Purpose:** let the maintainer and a future ChatGPT conversation restore the working context without relying on old chat history.

> IMPORTANT FOR A NEW CHAT: Read this file first, then read the current contents of both source files in the repository. Treat the repository as the source of truth for code. Treat this document as a handover note, not as a substitute for inspecting the current source. Distinguish facts verified in code from behavior reported by the maintainer on the local PC. Do not assume older chat messages describe the latest files.

## 1. Quick resume instructions

When starting a new ChatGPT conversation, the maintainer can provide this repository link:

https://github.com/AnAllegory/VoiceMeeter-IdleWatcher

Suggested instruction:

"Please read PROJECT_CONTEXT.md and inspect the current PS1 and VBS files in this private GitHub repository. Restore the project context from the repository. Before suggesting code changes, compare your understanding with the current source. Work one concrete step at a time and do not assume old chat history is available."

The GitHub connection was confirmed able to read this private repository on 2026-11-18. This does not guarantee that every new chat will automatically inspect it: explicitly ask the assistant to read the context file and current source files. Repository access also depends on the GitHub connection and its repository permissions still being enabled.

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
├── ARCHITECTURE.md
├── CHANGELOG.md
├── .github/
│   └── workflows/
│       └── powershell-check.yml
└── .gitignore
~~~

The repository is private. Do not add runtime logs, rotated logs, KeePass databases, passwords, tokens, recovery codes, or other secrets.

## 4. Source files and responsibilities

### VoiceMeeter-IdleWatcher.ps1

The main watcher. The current source has approximately 1,275 lines. It includes:

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
- Optional MacroButtons displayed-state synchronization through VBVMR_MacroButton_GetStatus and VBVMR_MacroButton_SetStatus in STATEONLY mode. The configured value is VoiceMeeter Remote API logical button ID 1 (ID 0 is reserved for the maintainer's microphone button). The displayed state is checked every 10 seconds, set to ON while the watcher process is active, and OFF during graceful cleanup. API or button unavailability is non-fatal and DEBUG-only.
- Revalidation of idle time and display state immediately before dispatching shutdown.
- Follow-up probes to detect whether VoiceMeeter stopped or restarted after a shutdown request.
- Cleanup that logs out of the API, unregisters display notifications, closes the stop event, and releases the watcher mutex.

Current code does NOT contain VBVMR_MacroButton_SetStatus and does NOT implement synchronization of the MacroButtons visual button state. Do not document that feature as implemented unless the source is changed and reviewed.

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
| EngineAbsentProbeIntervalSec | 3 seconds | Probe interval while VoiceMeeter engine is absent. |
| DisplayNotificationTimeoutSec | 5 seconds | Wait for an initial display-state notification. |
| PostShutdownProbeIntervalSec | 1 second | Prompt probe after shutdown request. |
| PostShutdownRestartProbeIntervalSec | 3 seconds | Probe interval while waiting for possible engine restart. |
| PostShutdownConfirmationTimeoutSec | 5 seconds | Confirmation window before retry logic. |
| ApiSessionRecoveryRetryIntervalSec | 5 seconds | Delay before API session recovery retry. |
| DebugMode | Off by default | Enabled by passing -DebugMode. |
| MacroButtonLogicalIndex | 1 | VoiceMeeter Remote API logical button ID to synchronize; ID 0 is reserved for the microphone button. Set to -1 to disable. |
| MacroButtonSyncIntervalSec | 10 seconds | Interval for reconciling displayed button state with watcher process state. |

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
- The script rechecks both idle duration and display state immediately before issuing shutdown.
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
System.Execute("%windir%\System32\cmd.exe","C:\Users\serge\Desktop\VoiceMeeter Automation","/C wscript.exe VoiceMeeter-IdleWatcher.vbs");
~~~

### STOP — Button OFF

~~~vb
System.Execute("%windir%\System32\cmd.exe","C:\Users\serge\Desktop\VoiceMeeter Automation","/C wscript.exe VoiceMeeter-IdleWatcher.vbs /stop");
~~~

The working directory is specific to the maintainer's current PC. If the project moves, update the working-directory field. Before making this repository public, remove or generalize this personal path in both README files and this context file.

## 9. Verified behavior reported by the maintainer

The following behavior was reported as successfully observed on the maintainer's PC:

- The exact MacroButtons START and STOP System.Execute commands above work.
- A normal graceful stop produced log messages including:
  - Logout succeeded (code 0).
  - Single-instance mutex released successfully.
  - Stop confirmed.
  - Watcher process cleanup sequence has ended.
- Stopping the watcher caused the relevant PowerShell process to exit.
- The user observed a VoiceMeeter Remote API indicator go dark when the watcher exited. Do not generalize this observation to every R indicator without further evidence.

These are user-reported local runtime observations. They are not the same as an independent test performed by ChatGPT.

## 10. Known limitations and open items

1. **MacroButtons visual-state synchronization is implemented but not yet verified on the maintainer's Windows system.** The watcher reads the configured button state and reconciles it every 10 seconds with Remote API STATEONLY mode. This changes only the visual state and does not execute the button macro. No helper process is created. The current target is logical button ID 1; logical ID 0 is reserved for the maintainer's microphone button.
2. If the configured button or MacroButtons API function is unavailable, synchronization is skipped and retried later. Repeated identical failures are suppressed and recorded only at DEBUG level; they do not stop the watcher.
3. The CI workflow performs syntax and static analyzer checks only. It does not execute the watcher or test actual VoiceMeeter/MacroButtons/display behavior.
4. No license has been chosen.
5. The repository currently documents the maintainer's local MacroButtons path. It is private; generalize that path before making the repository public.
6. Runtime behavior must still be confirmed on the maintainer's Windows system; GitHub Actions cannot independently verify the local VoiceMeeter engine, MacroButtons UI, or display hardware.

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
- It checks required repository files and parses the main PS1 source using the Windows PowerShell 5.1 parser. Parser errors fail the workflow.
- It installs PSScriptAnalyzer 1.25.0 and reports Error, Warning, and Information findings.
- Initial baseline mode is intentional: PSScriptAnalyzer findings are reported but do not yet fail the workflow. Review the first run before deciding which analyzer rules should become blocking.
- This is static analysis only. It does not execute the watcher, connect to VoiceMeeter, test MacroButtons, or verify actual display power notifications.

## 14. Change history

- `CHANGELOG.md` records the repository baseline and future notable changes.
- No numbered release has been declared yet; do not infer software versions from documentation commits.

## 15. Architecture documentation

- `ARCHITECTURE.md` contains a bilingual high-level description and Mermaid diagrams for the watcher’s main control flow, safety checks, and graceful stop path.
- Both README files include a concise overview diagram and link to the detailed architecture document.
- The diagram is intentionally high-level; retry, timeout, API recovery, and logging details remain defined by the current source code.

## 16. Current repository state at handover

At the time this context file is being prepared:

- Repository: AnAllegory/VoiceMeeter-IdleWatcher.
- Visibility: Private.
- Default branch: main.
- The repository contains the current PS1 and VBS source files, bilingual README files, project handover notes, architecture documentation, changelog, and automated PowerShell checks.
- GitHub connector read access to the private repository was successfully used in the current conversation.
- README.md and README.ru.md contain the English and Russian project documentation, including the main Mermaid flow diagram.
- PROJECT_CONTEXT.md is the handover document for restoring project context in a future chat.
- ARCHITECTURE.md contains the bilingual detailed architecture overview and Mermaid diagrams.
- The current source files were fetched back from GitHub for this review; their sizes were about 51 KB (PS1) and 7 KB (VBS).
- MacroButtons visual-state synchronization is implemented for VoiceMeeter Remote API logical button ID 1 (ID 0 is reserved for the mic), with STATEONLY and a 10-second reconciliation interval. Target-PC runtime verification is pending.
- The current PS1 source has no hard-coded C:\Users\serge path and no obvious API-token pattern was detected in a basic static scan. This is not a comprehensive security audit.

