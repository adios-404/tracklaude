# Claude Usage Tracker

A macOS menu-bar app that shows how much of the user's Claude rate limits are used
and when they reset. Built as an open-source, auditable replacement for Usage4Claude.

## Language

**Window**:
One rate-limit bucket Anthropic tracks for an account: the 5-hour window, the 7-day
window, or a per-model 7-day window.
_Avoid_: limit, bucket, quota

**Utilization**:
How much of a Window has been consumed, as a percentage from 0 to 100.
_Avoid_: usage, percent used, consumption

**Reset**:
The moment a Window's Utilization returns to zero. Each Window has its own Reset.
_Avoid_: expiry, rollover

**Time-to-Reset**:
The remaining duration until a Window's Reset, shown compactly (e.g. `2h14m`).
_Avoid_: countdown, ETA

**Credential**:
The OAuth refresh token the app holds to fetch usage on the user's behalf. Narrow
scope (`user:profile`); never a claude.ai session cookie.
_Avoid_: session key, token (ambiguous), API key

**Snapshot**:
One successful fetch of all Windows' Utilization and Reset at a point in time.
_Avoid_: response, reading, sample
