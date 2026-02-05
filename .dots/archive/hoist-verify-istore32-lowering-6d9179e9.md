---
title: Verify istore32 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T20:49:20.782875+01:00\""
closed-at: "2026-02-05T20:50:45.410054+01:00"
close-reason: Added ISLE coverage test asserting aarch64_istore32 (STR size32)
---

Context: src/codegen/compile.zig:4958; cause: ensure istore32 lowers to STR W-reg; fix: add/adjust AArch64 lowering test to assert STR size32 emission; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
