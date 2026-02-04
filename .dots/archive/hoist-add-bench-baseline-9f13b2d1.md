---
title: Add Bench Baseline
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.545680+01:00\""
closed-at: "2026-02-05T19:49:52.115427+01:00"
close-reason: Added bench-log step and recorded /tmp/hoist-bench.log
blocks:
  - hoist-add-baseline-checks-6731b0c3
---

Context: build.zig:1; cause: no perf baseline; fix: run zig build bench and save /tmp/hoist-bench.log; deps: hoist-add-full-test-53015783; verification: log saved + key timings recorded
