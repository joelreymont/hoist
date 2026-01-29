---
title: Add Optimizer Folding Tests
status: active
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.359020+01:00\""
---

Context: src/ir/optimize.zig:296; cause: missing coverage for const folding/strength reduce; fix: add tests for add/sub/mul/shift paths; deps: hoist-fix-optimizer-shift-6ac31625; verification: zig test src/ir/optimize.zig
