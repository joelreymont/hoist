---
title: Remove JIT test debug prints
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:44:09.021639+01:00\\\"\""
closed-at: "2026-02-06T21:45:20.269565+01:00"
close-reason: Cleaned noisy std.debug.print output from e2e tests
---

tests/e2e_jit.zig has unconditional std.debug.print blocks in ABI verification and codegen tests. Remove all debug output while keeping assertions unchanged. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
