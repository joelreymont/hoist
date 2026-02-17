---
title: Harden perf gate
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T12:20:48.807485+01:00\""
closed-at: "2026-02-17T12:27:56.616679+01:00"
close-reason: completed repeat baseline capture, median perf gate with JSON tracking, and strict build wiring for fresh baseline/current gating
---

files: build.zig, tools/baseline.zig, tools/perf_gate.zig, docs/COMPLETION_STATUS.md. cause: single-run noisy gate and weak dependency wiring can miss regressions. fix: multi-sample median gate + strict build wiring + machine-readable reports. why: stable regression prevention and performance tracking over time.
