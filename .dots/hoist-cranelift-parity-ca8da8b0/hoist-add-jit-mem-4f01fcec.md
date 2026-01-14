---
title: Add jit memory
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.641569+02:00"
---

Files: src/backends/aarch64/jit_harness.zig:1-139
Root cause: JIT memory management only exists in test harness.
Fix: extract reusable JIT memory manager in src/jit/memory.zig.
Why: cranelift-jit parity.
Deps: none.
Verify: JIT memory tests.
