# Security Policy

## Supported versions and repository scope

This policy applies to the public repository AnAllegory/VoiceMeeter-IdleWatcher.

A formal version support matrix has not been established. The latest stable public release is v1.0.5, published on 2026-11-22. The current `main` source is being prepared as the v1.0.6 maintenance candidate; it is not yet a published or tagged release. Public releases v1.0.0, v1.0.1 and v1.0.5 are available; v1.0.2 through v1.0.4 were internal development milestones, not separate public releases. The v1.0.5 tag points to the validated source commit ad60060dbe45323fb7c782ba6d4aa6df6b0b502f. Later commits on `main` do not change that tagged release. When reporting an issue, identify the exact commit SHA or public release tag you reviewed or tested.

## Reporting a vulnerability

**Do not disclose an unpatched security vulnerability through public GitHub Issues, pull requests, discussions, chat logs or other public channels.**

Use GitHub's private vulnerability reporting feature for this repository if it is enabled:

1. Open the repository's Security tab.
2. Choose Report a vulnerability, if that option is available.
3. Submit the report through GitHub's private advisory form.

If private vulnerability reporting is unavailable, contact the maintainer privately through the GitHub profile:

https://github.com/AnAllegory

Do not publish vulnerability details until the maintainer has had a reasonable opportunity to investigate and prepare a fix. No response-time or remediation-time guarantee is offered.

## What to include

Where possible, include:

- The affected commit SHA or release tag.
- The affected file, module, workflow or documented release artifact.
- A clear description of the security impact and the conditions required to reproduce it.
- Minimal reproduction steps or a safe proof of concept.
- Relevant error messages or logs after removing usernames, local paths, tokens and unrelated private information.
- Any known workaround or mitigation.

Do not send passwords, API tokens, recovery codes, private keys, KeePass databases, complete unredacted logs or unrelated personal data.

## Scope

Security reports may concern:

- The PowerShell watcher and its Windows API or VoiceMeeter Remote API integration.
- The VBS launcher and its process-starting or graceful-stop behavior.
- PowerShell modules, native C# interop and configuration handling.
- GitHub Actions workflows, build checks and repository automation.
- Project files and documented distribution artifacts.

Examples include unintended execution of attacker-controlled commands, exposure of secrets, unsafe handling of untrusted input, or a weakness that allows an attacker to bypass an important security boundary.

Ordinary bugs, reliability issues without a security impact, documentation corrections and feature requests are not security vulnerabilities. Use the repository's normal issue or pull-request process for those topics.

## Coordinated disclosure

Please allow the maintainer time to validate a report, assess its impact and prepare an appropriate fix before publicly disclosing technical details.

Reports are assessed individually. A report does not imply that the issue is confirmed or that a particular remediation timeline can be guaranteed.
