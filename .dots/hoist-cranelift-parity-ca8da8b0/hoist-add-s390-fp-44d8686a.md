---
title: Add s390 fp
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.465776+02:00\""
closed-at: "2026-01-23T14:13:11.073868+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/s390x/inst.zig (new)
Root cause: s390x FP/atomic inst coverage missing.
Fix: add FP and atomic inst variants to s390x Inst.
Why: parity with Cranelift s390x backend.
Deps: Add s390 insts.
Verify: inst format tests.
