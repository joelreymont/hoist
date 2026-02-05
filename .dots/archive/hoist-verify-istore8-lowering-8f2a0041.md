---
title: Verify istore8 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T20:49:12.065237+01:00\""
closed-at: "2026-02-05T20:50:35.657544+01:00"
close-reason: Added ISLE coverage test asserting aarch64_istore8 (STRB)
---

Context: src/codegen/compile.zig:4940; cause: ensure istore8 lowers to STRB; fix: add/adjust AArch64 lowering test to assert STRB emission; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
