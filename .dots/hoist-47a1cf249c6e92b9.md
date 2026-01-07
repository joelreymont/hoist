---
title: Fix CFG compute return type
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T12:49:10.853753+02:00"
closed-at: "2026-01-05T12:54:19.082191+02:00"
---

File: src/codegen/compile.zig:149 - Error: cfg.compute() returns void, not error union. Fix: Remove 'try' and 'catch', just call compute(). Blocks: test compilation.
