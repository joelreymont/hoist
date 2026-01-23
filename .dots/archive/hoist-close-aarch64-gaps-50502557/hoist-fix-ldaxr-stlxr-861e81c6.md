---
title: Fix ldaxr stlxr
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T14:45:27.500452+02:00\""
closed-at: "2026-01-14T14:49:24.879486+02:00"
close-reason: delegate to size-specific encoders
---

File: src/backends/aarch64/emit.zig:12805,12827. Root cause: generic emitLdaxr/emitStlxr encodes o1=0 so acquire/release bit is cleared for size-based forms. Fix: set o1 bit or delegate to emitLdaxrW/X and emitStlxrW/X with size switch; assert/guard sizes. Verify: zig build test --cache-dir /tmp/hoist-zig-cache --global-cache-dir /tmp/hoist-zig-global.
