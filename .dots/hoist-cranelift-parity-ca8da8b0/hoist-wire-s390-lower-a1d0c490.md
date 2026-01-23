---
title: Wire s390 lower
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.483145+02:00\""
closed-at: "2026-01-23T14:15:31.689553+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/lower.zig:12-55
Root cause: s390x lowering missing.
Fix: add src/backends/s390x/lower.isle and lower.zig for base lowering.
Why: IR->s390x lowering.
Deps: Add s390 insts.
Verify: lowering tests.
