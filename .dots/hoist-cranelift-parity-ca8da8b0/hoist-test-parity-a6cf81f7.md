---
title: Test parity
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:35.537172+02:00\""
closed-at: "2026-01-14T15:42:57.199939+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/README.md:46-50 (fuzzing + verification), ~/Work/wasmtime/cranelift/docs/testing.md:17-75 (filetests + filecheck), /Users/joel/Work/hoist/docs/feature_gap_analysis.md:127-129 (ISLE coverage/tests missing). Root cause: no clif filetests, limited fuzzing/coverage. Fix: add filetest harness, filecheck integration, fuzzing, regalloc verification, ISLE coverage tests. Why: parity with Cranelift testing rigor.
