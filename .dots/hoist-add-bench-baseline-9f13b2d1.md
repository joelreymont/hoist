---
title: Add Bench Baseline
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.545680+01:00"
blocks:
  - hoist-add-baseline-checks-6731b0c3
---

Context: build.zig:1; cause: no perf baseline; fix: run zig build bench and save /tmp/hoist-bench.log; deps: hoist-add-full-test-53015783; verification: log saved + key timings recorded
