---
title: Fix unsigned div/rem immediate bits
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:44:05.022678+01:00\""
closed-at: "2026-02-06T20:46:12.846532+01:00"
close-reason: Completed
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:4256 and 4307 treat udiv_imm/urem_imm immediates as signed i64 and cast with @intCast, which can trap for bit-pattern immediates like -1 (u64 max) and mis-handle high-bit constants. Cause: signed interpretation in unsigned lowering paths. Fix: use u64 bit-pattern via @bitCast for power-of-two checks, shift/mask computation, and mov_imm materialization; add lowering tests for -1 immediates. Deps: hoist-fix-div-rem-e090c1d9. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
