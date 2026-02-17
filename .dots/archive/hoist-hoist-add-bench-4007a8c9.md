---
title: Hoist add bench-compare step
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:00:29.292310+01:00\\\"\""
closed-at: "2026-02-17T17:01:07.243725+01:00"
close-reason: completed (added build step bench-compare + docs and validated compare-only run)
---

Full context: build.zig bench-gate always regenerates current log, which complicates same-tree A/B and can overwrite staged logs. Cause: no pure compare step for existing log files. Fix: add zig build step bench-compare that runs tools/perf_gate against provided baseline/current log paths without rerunning benchmarks. Update docs/COMPLETION_STATUS.md with usage. Proof: zig build bench-compare executes and writes report/json from fixed input logs.
