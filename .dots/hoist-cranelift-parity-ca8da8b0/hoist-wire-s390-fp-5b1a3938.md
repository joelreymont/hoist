---
title: Wire s390 fp
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.488993+02:00\""
closed-at: "2026-01-23T14:15:35.604470+02:00"
---

Files: src/backends/s390x/lower.isle (new), src/backends/s390x/inst.zig (new)
Root cause: s390x FP/atomic lowering rules missing.
Fix: add FP and atomic ISLE rules for s390x.
Why: full feature coverage.
Deps: Add s390 fp.
Verify: FP/atomic lowering tests.
