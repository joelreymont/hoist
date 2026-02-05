---
title: Fix regalloc silent skips
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T21:26:36.814752+01:00\\\"\""
closed-at: "2026-02-05T21:28:53.144633+01:00"
close-reason: Reject unsupported variants and add regression tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:220 and /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:348; cause: unsupported instructions are silently skipped in extract/apply paths; fix: return explicit errors and add regression tests; deps: stage regalloc parity tasks; verification: zig build test -j1 --global-cache-dir .zig-global-cache
