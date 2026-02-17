---
title: Wire release benchmark mode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.528071+01:00\""
closed-at: "2026-02-17T13:15:53.193792+01:00"
close-reason: completed release benchmark mode rollout with bench-optimize default ReleaseFast, release-default gate wiring validation, and benchmark profile documentation
---

Context: build.zig:52-72, build.zig:571-610; cause: perf numbers are often captured in Debug and are non-actionable for production throughput; fix: enforce release-mode benchmark/gate pathways and explicit build profile selection; deps: Drive 2x3x compile throughput; verification: benchmark logs show ReleaseFast and stable medians.
