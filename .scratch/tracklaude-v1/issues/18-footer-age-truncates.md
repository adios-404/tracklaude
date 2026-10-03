# 18: The footer's "Updated N s ago" truncates from 10 s

**What to fix:** at the popover's 300 pt width, the footer row (the reading's age, then
Refresh, Sign out, Quit) leaves the age text room for one digit of seconds only. From 10 s
it reads `Updated 13 s a…`. With 30 s polling the age has two digits about two thirds of
the time, so most opens show a cut-off line.

**Blocked by:** none

**Status:** needs-triage

- [ ] The age text never truncates at the popover's width, for any value `UpdatedAgoText`
      produces (`59 s ago`, `59 min ago`, `23 h ago`)
- [ ] Checked by rendering the popover with a reading 59 s old, e.g. through
      `Scripts/readme-art` with `fetchedAt` moved back

## Comments

**2026-10-03.** Found while drawing the README's pictures from the real `PopoverView`
(`Scripts/readme-art`): the dark render landed 13 s after the sample reading and came out
`Updated 13 s a…`; the owner's own screenshot from ticket 10 shows `Updated 10 s a…`. The
README pictures avoid it by using a reading 4 s old, so they are true to the app but show
its best case. Options, the owner's call: shorter text (`13 s ago`), give the label layout
priority over the buttons, or move Sign out out of the row. A fix needs a release, and each
release costs the owner two Keychain prompts, so batch it with other changes.
