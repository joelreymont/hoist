---
title: Harden a64 alloc rewrite
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T09:42:32.609049+01:00\""
closed-at: "2026-02-07T09:45:12.906731+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isa.zig applyAllocations() had default else that silently skipped register rewriting for unhandled instruction variants. Cause: silent rewrite skips can produce latent miscompiles when linear-scan path or test harnesses hit new variants. Fix: return explicit error for unhandled variants instead of no-op. Verification: zig build test -j1 --global-cache-dir .zig-global-cache and zig build fuzz.
