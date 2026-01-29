---
title: Add Optimizer Folding Tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.359020+01:00\\\"\""
closed-at: "2026-01-29T10:20:16.937664+01:00"
close-reason: done
---

Context: src/ir/optimize.zig:296; cause: missing coverage for const folding/strength reduce; fix: add tests for add/sub/mul/shift paths; deps: hoist-fix-optimizer-shift-6ac31625; verification: zig test src/ir/optimize.zig
