---
title: Fix JIT Panics/Unreachable
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.536801+01:00"
---

Context: src/jit/module.zig:206; cause: @panic/orelse unreachable in JIT; fix: return errors and handle missing blobs/symbols; deps: hoist-fix-data-init-4652c8b0; verification: e2e_jit
