# VoiceMeeter IdleWatcher v1.0.0

## Release status

Published on 2026-11-19 as GitHub Release v1.0.0. The tag points to commit `44ee9d4f0bd404a4c8d0d4008523010ea2c07a7c`, which passed the Windows PowerShell 5.1 GitHub Actions workflow.

## Highlights

- Monitors Windows idle time and display power state.
- Requests VoiceMeeter shutdown only after the configured idle threshold has elapsed and the display is fully Off.
- Treats On, Dimmed, and unknown display states as conditions that block automatic shutdown.
- Uses VoiceMeeter Remote API with DLL discovery, API recovery, single-instance protection, and graceful stop handling.
- Supports optional MacroButtons visual-state synchronization using STATEONLY, so state updates do not execute the button macro.
- Provides primary, fallback, and emergency logging.

## Requirements

- Windows and Windows PowerShell 5.1.
- VoiceMeeter installed with the matching Remote API DLL.
- Windows Script Host enabled for the VBS launcher.

## Validation

- GitHub Actions Windows PowerShell 5.1 parser check passed.
- MacroButtons STATEONLY source contract check passed.
- Embedded Remote API interop C# compilation passed.
- PSScriptAnalyzer completed with one known PSReviewUnusedParameter warning for StartupStatusFile. The parameter is used by the nested Write-StartupStatus function; the warning is documented in source.
- MacroButtons visual-state synchronization was confirmed by the maintainer on the target Windows system.
- The main idle/display/shutdown scenario was observed successfully on the target Windows system.
- Long-duration operation and Windows sleep/wake recovery remain under observation. These are known limitations, not claims of completed validation.

## Installation

Keep VoiceMeeter-IdleWatcher.ps1 and VoiceMeeter-IdleWatcher.vbs in the same folder. Start with:

```text
wscript.exe VoiceMeeter-IdleWatcher.vbs
```

Stop gracefully with:

```text
wscript.exe VoiceMeeter-IdleWatcher.vbs /stop
```

See README.md and README.ru.md for configuration and MacroButtons setup.
