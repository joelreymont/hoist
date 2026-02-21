---
title: liveness cfg sorted ranges
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:05:09.373100+01:00\\\"\""
closed-at: "2026-02-21T21:09:50.815139+01:00"
close-reason: "completed: retained gate pass (/tmp/hoist-2x-loop-report-r9.md), 2x budget still failing"
---

Context: src/regalloc/liveness.zig computeLivenessWithCFGInto appends unsorted ranges and allocator sorts later; fix: sort ranges once in liveness path and mark ranges_sorted_by_start=true to remove repeated sort overhead.
