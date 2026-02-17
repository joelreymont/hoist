---
title: Add vcode clear-retain path
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.873783+01:00\\\"\""
closed-at: "2026-02-17T13:38:14.227318+01:00"
close-reason: implemented and benchmarked VCode clear-retain reuse path, but discarded per policy after 5-run incremental comparison showed large regressions (e.g. large100 +27.01%, large500 +21.89%, large5000 +9.83%; report /tmp/hoist-vcode-dot-report.md) and no >=5% improvement
---

Context: src/machinst/vcode.zig:93-99; cause: deinit/init cycles trigger allocator churn; fix: add clearRetainingCapacity API for VCode buffers and use it on reuse path; deps: Reuse codegen allocations; verification: compile loop no longer deinitializes/reinitializes VCode each iteration.
