---
title: Add cs* and ngc insts
status: closed
priority: 1
issue-type: task
created-at: "2026-01-14T13:02:45.984168+02:00"
---

Files: src/backends/aarch64/inst.zig:433, src/backends/aarch64/inst.zig:541, src/backends/aarch64/emit.zig:1668, src/backends/aarch64/emit.zig:1733, src/backends/aarch64/emit.zig:1754, src/backends/aarch64/emit.zig:1776, src/backends/aarch64/emit.zig:1444, src/backends/aarch64/isa.zig:1035. Root cause: emit has csinc/csinv/csneg/ngc helpers but Inst variants, formatting, operand collection, and reg rewrite are missing; tests use csel/neg with mismatched expectations. Fix: add Inst variants + format + getOperands + reg rewrite; add emit switch cases; update tests to emit correct variants (csinc/csinv/csneg/ngc). Verify: encoding tests in src/backends/aarch64/emit.zig pass.
closed-at: "2026-01-23T08:46:55+02:00"
close-reason: already complete
