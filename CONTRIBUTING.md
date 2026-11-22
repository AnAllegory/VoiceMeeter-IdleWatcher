# Contributing

Thank you for taking an interest in VoiceMeeter IdleWatcher. Bug reports, focused improvements and documentation corrections are welcome.

This is a small Windows utility with a deliberately conservative shutdown and API lifecycle design. Please read these guidelines before proposing implementation changes.

## Before opening a pull request

- **Bug reports:** open an Issue using the Bug report form. Include the exact release tag or commit SHA and concise reproduction steps.
- **Feature ideas:** open an Issue using the Feature request form, or start a Discussion for an early design conversation. Significant behavior or architecture changes should be discussed before implementation.
- **Security vulnerabilities:** do not report an unpatched vulnerability in a public Issue or Discussion. Follow [SECURITY.md](SECURITY.md).
- **Questions:** use [GitHub Discussions](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/discussions).

Please check existing Issues and Discussions before creating a duplicate.

## Development environment

The supported runtime target is:

- Windows.
- Windows PowerShell 5.1 (Desktop edition). Do not introduce PowerShell 7-only syntax or dependencies.
- VoiceMeeter with its Remote API for manual runtime testing.

Keep all seven runtime files together in the application directory. Preserve the module import order:

Support -> Interop -> MacroButtons

Use tabs, not spaces, for indentation in PowerShell, VBS and C# source files. Preserve the existing C# DLL-path marker contract: __VOICEMEETER_DLL_PATH__ must occur exactly once in the verbatim string and be replaced by the Interop module using UTF-8 source reading and quote escaping.

## Safety and architecture contracts

Changes to the implementation must preserve the current safety model unless a separately discussed design change is explicitly approved:

1. Automatic VoiceMeeter shutdown requires the configured idle threshold and a display state of fully Off (0). On, Dimmed, unknown or unavailable display states must block shutdown.
2. Recheck idle, display state and graceful /stop immediately before Command.Shutdown. Do not weaken or bypass the final validation.
3. MacroButtons is optional and non-fatal. Keep one writer, Invoke-MacroButtonStateSync.
4. Keep STATEONLY (0x00000002) fixed in the MacroButtons module. Do not make the bitmode configurable and do not add GetStatus readback or MacroButton_IsDirty polling.
5. Send MacroButtons writes only when API state is known and the VoiceMeeter engine is confirmed running. After IsParametersDirty = -2 confirms server teardown, do not attempt further writes; retain the last API-accepted state.
6. Do not add process polling, WMI subscriptions, Process.Exited handlers or a second MacroButtons writer as workarounds for API teardown.
7. A successful Remote API return code means the command was accepted. It is not proof that the MacroButtons UI visibly changed.

These are intentional project contracts, not incidental implementation details. Read [ARCHITECTURE.md](ARCHITECTURE.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md), [ROADMAP.md](ROADMAP.md) and [AGENTS.md](AGENTS.md) before changing related code.

## Tests and evidence

The public GitHub Actions workflow runs Windows PowerShell 5.1 parsing, project-contract checks, C# interop compilation with a placeholder DLL path, VBS invalid-argument validation and PSScriptAnalyzer. A passing CI run is a static validation result; it does not launch VoiceMeeter or verify the live Remote API or MacroButtons UI.

For a code change:

- Run the relevant checks locally when possible and describe exactly what was run.
- Let the pull-request workflow run and address blocking failures.
- If you performed a manual runtime test, report the Windows and VoiceMeeter versions, the exact project tag or commit, the steps and the observed result.
- Clearly distinguish source inspection, static CI results and maintainer-reported runtime observations. Do not describe one as another.

Never include passwords, API tokens, recovery codes, private keys, unredacted logs, personal data or unrelated local paths in an Issue or pull request.

## Pull requests

1. Create a focused branch from the current public main branch.
2. Keep the change set small and explain the problem it solves.
3. Link the related Issue when one exists.
4. Describe behavior changes, compatibility impact and validation evidence.
5. Update both README files when user-facing behavior or instructions change.
6. Update relevant architecture, roadmap, changelog or release documentation when the change affects those records.
7. Do not create or move public release tags, publish releases or change version numbers as part of routine work. Release publication is a separate maintainer-controlled action.

A pull request is a proposal for review, not an automatic promise that the change will be merged.

## Community standards

Participation is covered by the [Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you agree to follow it.

For the Russian version of these guidelines, see [CONTRIBUTING.ru.md](CONTRIBUTING.ru.md).
