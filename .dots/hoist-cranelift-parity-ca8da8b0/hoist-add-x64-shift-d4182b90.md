---
title: Add x64 shift
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:39:55.108563+02:00\""
closed-at: "2026-01-23T10:04:25.524170+02:00"
---

Files: src/backends/x64/inst.zig:12-93
Root cause: shift/rotate insts are missing.
Fix: add shl/shr/sar/rol/ror with imm and CL forms.
Why: required for shift/rotate IR ops.
Deps: Add x64 alu.
Verify: extend inst format tests in src/backends/x64/inst.zig.
