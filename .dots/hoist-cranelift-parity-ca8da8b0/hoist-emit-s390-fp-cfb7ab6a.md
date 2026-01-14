---
title: Emit s390 fp
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.477114+02:00"
---

Files: src/backends/s390x/emit.zig (new), src/backends/s390x/inst.zig (new)
Root cause: s390x FP/atomic encoders missing.
Fix: add encoders for FP and atomic insts.
Why: FP/atomic ops correctness.
Deps: Add s390 fp, Emit s390 base.
Verify: FP/atomic encoding tests.
