# VoiceMeeter IdleWatcher v1.0.0

## Release status

Release candidate prepared on 2026-11-19. This file contains the proposed first-release notes. The v1.0.0 tag and published GitHub Release must be created only after the final Windows runtime observation and a successful workflow run on the exact release commit.

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
- Long-duration operation and Windows sleep/wake recovery remain under observation.

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
