---
title: Add s390 tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.512747+02:00"
---

Files: tests (new), src/backends/s390x/emit.zig (new)
Root cause: no s390x encoding/lowering tests.
Fix: add encoding + lowering tests for s390x base/FP/atomics.
Why: parity and regression coverage.
Deps: Emit s390 base, Emit s390 fp, Wire s390 lower.
Verify: zig build test.
