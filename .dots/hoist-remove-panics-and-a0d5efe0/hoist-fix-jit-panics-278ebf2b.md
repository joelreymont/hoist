---
title: Fix JIT Panics/Unreachable
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.536801+01:00\\\"\""
closed-at: "2026-02-01T20:39:03.764033+01:00"
close-reason: "completed: JIT paths return errors for missing functions/data/symbols (src/jit/module.zig:269-315); no panics/unreachable in src/jit"
---

Context: src/jit/module.zig:206; cause: @panic/orelse unreachable in JIT; fix: return errors and handle missing blobs/symbols; deps: hoist-fix-data-init-4652c8b0; verification: e2e_jit
