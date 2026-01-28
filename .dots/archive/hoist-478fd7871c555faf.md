---
title: Fix CallingConvention.C in e2e_jit
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:23:02.115425+02:00"
closed-at: "2026-01-04T15:23:47.895080+02:00"
---

Files: tests/e2e_jit.zig:144,216,289 - Error: union 'builtin.CallingConvention' has no member named 'C'. Zig 0.15 changed CallingConvention.C to .c (lowercase). Need to update all occurrences.
