---
title: 2x perf deep loop
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.496468+01:00\\\"\""
closed-at: "2026-02-21T20:01:23.044919+01:00"
close-reason: "completed: all child dots resolved by gate"
---

Context: src/codegen/compile.zig:844-937, src/regalloc/liveness.zig:330-608, src/regalloc/linear_scan.zig:343-573; cause: stage medians show lower/regalloc/rewrite/emit dominate; fix: execute deep-review architecture plan with strict perf gate >=5% retained gains; deps: none; verification: repeat-9 bench + bench-compare + zig build test.
