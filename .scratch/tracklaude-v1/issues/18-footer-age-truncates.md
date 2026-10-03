# 18: The footer's "Updated N s ago" truncates from 10 s

**What to fix:** at the popover's 300 pt width, the footer row (the reading's age, then
Refresh, Sign out, Quit) leaves the age text room for one digit of seconds only. From 10 s
it reads `Updated 13 s a…`. With 30 s polling the age has two digits about two thirds of
the time, so most opens show a cut-off line.

**Blocked by:** none

**Status:** done (2026-10-03, commits 5d189d1 and 1dd5903; Release v1.0.4; homebrew-tap PR #10)

- [x] The age text never truncates at the popover's width, for any value `UpdatedAgoText`
      produces (`59 s ago`, `59 min ago`, `23 h ago`)
- [x] Checked by rendering the popover with a reading 59 s old, e.g. through
      `Scripts/readme-art` with `fetchedAt` moved back

## Comments

**2026-10-03.** Found while drawing the README's pictures from the real `PopoverView`
(`Scripts/readme-art`): the dark render landed 13 s after the sample reading and came out
`Updated 13 s a…`; the owner's own screenshot from ticket 10 shows `Updated 10 s a…`. The
README pictures avoid it by using a reading 4 s old, so they are true to the app but show
its best case. Options, the owner's call: shorter text (`13 s ago`), give the label layout
priority over the buttons, or move Sign out out of the row. A fix needs a release, and each
release costs the owner two Keychain prompts, so batch it with other changes.

**2026-10-03, done.** The owner said "fix the two bugs"; of the options above, none was
taken: the popover is 320 pt wide instead of 300, so every word and button stays. Measured
the footer's natural width with the real controls (`.caption` age, `.small` buttons, plus
the 12 pt padding each side): 294 pt for `Updated 9 s ago`, 300.5 for `Updated 13 s ago`
(so 300 missed by half a point), 312.5 for `Updated 59 min ago`, the longest, 307.5 for
`Updated 123 h ago`, 292 for `Not updated yet`. Rendering the real `PopoverView` at 320
with readings 13 s, 59 min and 123 h old showed each in full. 154 tests pass; the README
hero was redrawn at the new width (`make readme-art`).

On the real app: v1.0.4 via `brew upgrade`, first launch 13:19:34 — two Keychain prompts
(13:19:34, 13:19:40), `State: signedOut → polling`, `Usage fetch issued (timer)`, no
failure; the menu bar read `98% · 3h10m` through AX. The popover was not opened by the
agent (a CGEvent click no longer opens it), so the footer's layout rests on the render of
the real view.

