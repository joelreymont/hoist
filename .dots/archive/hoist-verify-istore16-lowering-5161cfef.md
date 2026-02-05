---
title: Verify istore16 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T20:49:15.472328+01:00\""
closed-at: "2026-02-05T20:50:42.278312+01:00"
close-reason: Added ISLE coverage test asserting aarch64_istore16 (STRH)
---

Context: src/codegen/compile.zig:4949; cause: ensure istore16 lowers to STRH; fix: add/adjust AArch64 lowering test to assert STRH emission; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
