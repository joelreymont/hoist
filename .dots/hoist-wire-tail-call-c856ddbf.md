---
title: Wire tail call indirect
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:32.744820+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3316, wire indirect tail call with stack args. Deps: Add tail call stack copy. Verify: zig build test
