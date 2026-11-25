# Project history and modular integration

## Current repository

The canonical repository is AnAllegory/VoiceMeeter-IdleWatcher. The public main branch is the home for current source, documentation, CI and GitHub Pages.

The v1.0.6 maintenance source was merged into public `main` through PR #13 (merge commit `c71b20d6f4b6987be3b66758073fe325fddb4209`) and passed static CI plus maintainer-reported target-PC runtime validation on 2026-11-24. PR #15 added the published Defender notice and produced the release snapshot at commit `d693ae05e28199b40ed10feae24c42b0a96d9f40`; the immutable `v1.0.6` tag and stable GitHub Release were published on 2026-11-24. PR #17 reconciled release documentation on `main`, and PR #18 updated the tagged source links on `gh-pages`. The public v1.0.0, v1.0.1 and v1.0.5 tags remain unchanged historical releases; the `v1.0.5` tag points to validated commit `ad60060dbe45323fb7c782ba6d4aa6df6b0b502f`. The current release is [v1.0.6](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/releases/tag/v1.0.6).

## How the project reached the modular source

The project began in the public repository as a monolithic PowerShell implementation. The public main branch at commit 4173af2229198b47f8fa2cb0056baadc1c7e4166 was the integration base and contained the monolithic source line.

The modular source was developed in the private workspace AnAllegory/VoiceMeeter-IdleWatcher-Beta, beginning with a maintainer-provided seven-file working archive dated 2026-11-21. Its internal source milestones were v1.0.2 through v1.0.5:

- v1.0.2: initial modular split.
- v1.0.3: STATEONLY, configuration and API lifecycle hardening.
- v1.0.4: pre-shutdown 1000ms allowance followed by final safety revalidation.
- v1.0.5: no-server write gate for periodic and manual MacroButtons synchronization.

The modular implementation was integrated into the original public repository through PR #10 and is now maintained from the public main branch. The private Beta repository remains a separate historical workspace and is not the canonical source for future public development.

The repositories do not share an asserted direct Git parent/child history. The merge preserved the public repository's existing commit history rather than replacing it with the private Beta history.

## Modular source layout

| Component | Responsibility |
|---|---|
| VoiceMeeter-IdleWatcher.ps1 | Main orchestrator, configuration validation, monitoring loop and shutdown flow |
| VoiceMeeter-IdleWatcher.psd1 | Runtime configuration |
| VoiceMeeter-IdleWatcher.vbs | Hidden launcher, startup status and graceful stop |
| VoiceMeeter-IdleWatcher.Support.psm1 | Logging, startup status, stop and refresh support |
| VoiceMeeter-IdleWatcher.Interop.psm1 | DLL discovery, C# source preparation and Remote API setup |
| VoiceMeeter-IdleWatcher.MacroButtons.psm1 | Single STATEONLY writer and last-write status |
| VMRIdleWatcherNative.cs | Windows and VoiceMeeter native interop |

The required module import order is Support -> Interop -> MacroButtons. Keep all implementation files together in the application directory.

## Preserved safety model

Both the monolithic and modular lines are based on the same central condition:

- The configured idle threshold must be reached.
- The display must be fully Off (0).
- On (1), Dimmed (2), unknown or unavailable display state blocks automatic shutdown.
- A graceful /stop request blocks shutdown.
- Final idle/display/stop checks run immediately before Command.Shutdown.
- Stopping the watcher does not shut down VoiceMeeter.

The modular source additionally preserves Windows PowerShell 5.1 compatibility, single-instance protection, graceful cleanup, Remote API recovery, bounded shutdown retries and optional/non-fatal MacroButtons synchronization.

## CI history

The original public workflow validated a monolithic source file. The current workflow validates the modular source layout, checks PowerShell 5.1 parsing and project contracts, enforces tabs in source files, compiles the embedded C# interop with a placeholder DLL path, checks the no-log gap between final safety validation and shutdown dispatch, exercises the VBS invalid-argument path without launching the watcher, and runs PSScriptAnalyzer on the orchestrator and PowerShell modules. Error-level analyzer findings block CI; Warning and Information findings remain non-blocking.

The monolithic and modular workflows are not interchangeable. Keep CI aligned with the actual source tree.

## Release status

The public releases v1.0.0, v1.0.1 and v1.0.5 remain unchanged historical releases; v1.0.6 is the latest stable release, published on 2026-11-24. The implementation milestones v1.0.2 through v1.0.4 were internal development stages, not separate public tags. The v1.0.5 release discussion is [#11](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/discussions/11); the current [v1.0.6 GitHub Release](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/releases/tag/v1.0.6) contains the latest release notes and Portable ZIP link.
