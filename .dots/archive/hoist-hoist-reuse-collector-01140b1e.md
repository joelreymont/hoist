---
title: hoist-reuse-collector-v2
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:21:30.273309+01:00\\\"\""
closed-at: "2026-02-18T09:26:36.908786+01:00"
close-reason: "completed: immediate repeat-9 A/B showed qualifying gains on int/vector/memory/mixed with zero regressions"
---

src/codegen/compile.zig insertSpillScratch second pass still allocates/deallocates OperandCollector per instruction; with first pass removed, retest per-block collector reuse using clearRetainingCapacity to cut allocation churn, then gate with immediate repeat-9 A/B
