---
title: Verify istore32 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T21:16:55.813365+01:00\""
closed-at: "2026-02-05T21:17:05.237762+01:00"
close-reason: Emit STR (size32) and add store32 lowering test
---

Full context: /Users/joel/Work/hoist/src/backends/aarch64/isle_impl.zig:3330 and /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig:351; cause: aarch64_istore32 constructor returned Inst without emitting; fix: emit STR (size32) and add lowering test; verification: zig build test -j1 --global-cache-dir .zig-global-cache
