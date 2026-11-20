# VoiceMeeter IdleWatcher — Roadmap

This document records potential future improvements and deliberate scope decisions. It is a planning note, not a promise that every item will be implemented.

The current release is considered stable on the maintainer's observed normal operating path. Changes should be driven by a reproducible issue, a concrete use case, or a clear maintenance benefit. Do not add complexity merely because it is technically possible.

## Potential improvements

These items are retained for future reference. None is currently a confirmed defect requiring an immediate code change.

### 1. Remote Desktop (RDP) behavior

An RDP session disconnect may appear to the session as display Off. In that situation, the existing safety conditions may allow VoiceMeeter shutdown.

- Revisit this only if the maintainer uses RDP and this behavior becomes undesirable.
- Any change should be based on a concrete expected behavior for connected, disconnected, and reconnected sessions.

### 2. Sleep / Wake observation

The code does not currently implement dedicated Sleep / Wake handling.

- Existing logs have shown normal display-state transitions after observed activity, but they do not by themselves prove every Sleep / Wake scenario.
- Continue observing normal operation.
- Do not add dedicated sleep-resume logic unless a reproducible problem is found.

### 3. CI analyzer policy

PSScriptAnalyzer findings are currently reported without failing the workflow.

- Consider making analyzer findings at severity Error fail the workflow.
- Keep Warning and Information findings non-blocking unless there is a specific reason to change the policy.
- The known StartupStatusFile warning may be a false positive because the parameter is used by a nested function; verify before treating it as a source defect.

### 4. Logging clarity

If real troubleshooting needs arise, consider making the origin and reason for START / STOP requests easier to identify in the log.

Do not expand logging without a concrete diagnostic benefit.

## Deliberately out of scope for now

The following ideas were considered and intentionally deferred. Reconsider them only if a real use case appears.

- **Audio signal-level monitoring:** the utility is not an audio activity monitor. No demonstrated scenario currently justifies adding signal analysis.
- **Sound notifications:** not required for the current workflow.
- **External configuration file:** current source configuration is sufficient; avoid adding another configuration surface without need.
- **WhatIf or extra operating modes:** no current workflow requires them.
- **More elaborate log rotation:** existing limits and rotation are sufficient unless actual log-management problems appear.
- **Broad architectural refactoring:** do not restructure stable code solely for stylistic or theoretical reasons.

## Working principles

1. Fix demonstrated problems, not hypothetical ones.
2. Preserve the current fail-safe behavior: unknown, On, or Dimmed display state must not permit automatic shutdown.
3. Keep changes small and tied to a clear benefit and test scenario.
4. Treat local runtime observations as maintainer-reported evidence, distinct from CI static checks.
5. Do not change code, release versions, or tags merely to make progress on this list.

## Status

No roadmap item above is an active implementation task. The list is a place to preserve decisions and revisit them when circumstances justify it.
