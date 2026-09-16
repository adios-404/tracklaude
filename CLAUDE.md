# claudeusagetrackercustom

A from-scratch macOS menu-bar app that shows Claude usage limits, built to replace
Usage4Claude with something the owner fully controls and trusts with their session token.

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), recorded as a `Status:` line in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at the repo root and ADRs in `docs/adr/`. See `docs/agents/domain.md`.

## Ticket loop (`/implement` with no arguments)

The owner works by `/clear` → `/implement` → repeat. When `/implement` (or
`/mattpocock-skills:implement`) is invoked without a path:

1. **Pick the ticket yourself.** Target = the lowest-numbered file in
   `.scratch/tracklaude-v1/issues/` whose `Status:` is `ready-for-agent` and whose every
   `Blocked by:` ticket is `done`. State which one you picked and start; do not ask.
2. **Seams are pre-agreed.** The ticket's checklist plus `spec.md › Testing Decisions` define
   what is tested and what is not (real Keychain, real URLSession, socket handling are not).
   Skip the TDD skill's "confirm seams with the user" step.
3. **Verify on the real app** with `make run` (the first launch of every rebuild asks the
   owner for their password twice — Keychain ACL vs. ad-hoc cdhash, not a bug), then `log show --predicate 'process == "tracklaude"'`
   and `security find-generic-password -s com.adios404.tracklaude` (never `-w`). Try the
   computer-use tools for clicking the menu-bar item before asking the owner to. Ask the
   owner only for things that must be theirs: the browser OAuth consent, and reading a
   macOS dialog you cannot see. One question per turn, with a default.
4. **Close the ticket in the file:** tick the boxes, set `**Status:** done (date, commits)`,
   append findings under `## Comments` (what deviated from the spec and why, what the next
   ticket needs to know), and add a short handoff note to the next ticket's `## Comments`.
5. **Commit at milestones, push at close.** Conventional-commit messages explaining *why*.
   Push `main` when the ticket is closed so CI runs, then report the CI result in the
   final message. If CI fails, fix it in the same session.
6. **CI is stricter than local.** The runner's Swift Testing (Swift 6.0.x) rejects `await`
   inside `#expect(...)`; hoist awaited values into a `let` first. Local Swift 6.2 accepts both.
7. **Update memory** only for durable findings (toolchain quirks, verified facts with dates).

Read the previous ticket's `## Comments` before starting — that is where the handoff lives.
