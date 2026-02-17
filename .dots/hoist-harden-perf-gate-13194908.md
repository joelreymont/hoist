---
title: Harden perf gate
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T12:20:48.807485+01:00"
---

files: build.zig, tools/baseline.zig, tools/perf_gate.zig, docs/COMPLETION_STATUS.md. cause: single-run noisy gate and weak dependency wiring can miss regressions. fix: multi-sample median gate + strict build wiring + machine-readable reports. why: stable regression prevention and performance tracking over time.
