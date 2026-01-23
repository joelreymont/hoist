---
title: Add s390 regs
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.453505+02:00\""
closed-at: "2026-01-23T14:11:40.013588+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/regs.zig:1-60
Root cause: s390x backend missing register definitions.
Fix: add src/backends/s390x/regs.zig with GPR/FPR definitions and helpers.
Why: register file needed for backend.
Deps: none.
Verify: add s390x reg tests.
