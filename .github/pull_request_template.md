## What and why

<!-- What this changes, and why. Link the issue for a large change. -->

## Checklist

- [ ] `make test` passes.
- [ ] `make trust` passes.
- [ ] No new hostname, including one assembled at runtime, which the hostname check cannot see.
- [ ] No new way to log or write files: log lines go through `AppLog`, and nothing writes a file.
- [ ] README updated if behaviour changed.
