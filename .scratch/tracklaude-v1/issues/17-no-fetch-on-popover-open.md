# 17: No fetch on popover open (v1.0.3)

**What to build:** opening the popover shows the last reading and does not fetch; Refresh
is the explicit way to ask. The owner's call (2026-10-03) after learning each open fired a
request. Since 2026-10-02 16:00 popover opens were 11 of 632 requests — not the cause of the
refusals (ticket 16), but pure cost, and at 01:35 and 01:36 the popover's own fetch was the
one refused, so the banner appeared the moment the owner looked.

**Blocked by:** 16 Quiet rate limits

**Status:** done (2026-10-03, commit 3f468bb; Release v1.0.3; homebrew-tap PR #8)

- [x] `PollTrigger.popoverOpened` removed (not skipped), so nothing can reintroduce it by accident
- [x] `PopoverView.onAppear` keeps re-reading alert permission and the login item, nothing else
- [x] Tests, README and spec updated (supersedes ticket 04's "Opening the popover triggers a fetch")
- [x] On the real app: after the owner opened the popover on v1.0.3, every fetch in the log is `(timer)`

## Comments

**2026-10-03.** The popover's "Updated N s ago" footer already shows how old the reading is,
and it is never more than 30 s old while polling, or up to 10 min during a quiet rate limit
(ticket 16). 154 tests at release (the popover-open test went with the trigger).
