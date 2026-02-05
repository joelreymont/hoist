---
title: Verify istore8 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T21:16:48.327099+01:00\""
closed-at: "2026-02-05T21:16:58.990801+01:00"
close-reason: Emit STRB and add store8 lowering test
---

Full context: /Users/joel/Work/hoist/src/backends/aarch64/isle_impl.zig:3296 and /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig:339; cause: aarch64_istore8 constructor returned Inst without emitting; fix: emit STRB and add lowering test; verification: zig build test -j1 --global-cache-dir .zig-global-cache
