# Security Policy

## Supported versions

VoiceMeeter IdleWatcher is a small, actively maintained project. A formal version support matrix has not been established.

When reporting a security issue, please identify the exact release tag or commit you tested. Security fixes, when applicable, are expected to be developed against the current code in the `main` branch. Users should update to the latest available project version after a fix is published.

## Reporting a vulnerability

**Please do not report undisclosed security vulnerabilities through public GitHub Issues, Discussions, or pull requests.**

Use GitHub's private vulnerability reporting feature for this repository, if it is enabled:

1. Open the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Submit the report privately through GitHub's advisory form.

If private vulnerability reporting is unavailable, contact the repository maintainer privately through the GitHub profile:

https://github.com/AnAllegory

Do not publish vulnerability details until the maintainer has had a reasonable opportunity to investigate and prepare a fix. No response-time or remediation-time guarantee is currently offered.

## What to include

A useful report should include, where possible:

- The affected release tag or commit SHA.
- The affected file, component, or workflow.
- A clear description of the security impact and conditions required to reproduce it.
- Minimal reproduction steps or a safe proof of concept.
- Relevant logs or error messages, with usernames, local paths, tokens, and other private information removed.
- Any known workaround or mitigation.

Please avoid sending passwords, API tokens, recovery codes, private keys, or unrelated personal data.

## Scope

Security reports are relevant to vulnerabilities in the project repository, including:

- The PowerShell watcher and its Windows API or VoiceMeeter Remote API integration.
- The VBScript launcher and its process-starting or stop-control behavior.
- Build, automation, and GitHub Actions workflow configuration.
- Project release or distribution files maintained in this repository.

Examples of potentially relevant issues include unintended execution of attacker-controlled commands, exposure of secrets, unsafe handling of untrusted input, or a vulnerability that allows an attacker to bypass an important security boundary.

Unexpected application behavior, ordinary bugs, feature requests, and reliability issues that do not have a security impact should be reported through the project's regular GitHub Issues.

## Coordinated disclosure

Please allow the maintainer time to validate a report, assess its impact, and prepare an appropriate fix before publicly disclosing technical details.

The maintainer may ask follow-up questions or request additional evidence. Reports are assessed individually; submitting a report does not imply that the issue is confirmed or that a particular timeline for a fix can be guaranteed.
