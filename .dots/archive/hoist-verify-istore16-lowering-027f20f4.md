---
title: Verify istore16 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T21:16:52.127346+01:00\""
closed-at: "2026-02-05T21:17:02.674663+01:00"
close-reason: Emit STRH and add store16 lowering test
---

Full context: /Users/joel/Work/hoist/src/backends/aarch64/isle_impl.zig:3312 and /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig:345; cause: aarch64_istore16 constructor returned Inst without emitting; fix: emit STRH and add lowering test; verification: zig build test -j1 --global-cache-dir .zig-global-cache
