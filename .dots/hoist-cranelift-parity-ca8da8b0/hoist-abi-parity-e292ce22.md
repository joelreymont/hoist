---
title: ABI parity
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:21.139961+02:00\""
closed-at: "2026-01-14T15:42:57.162417+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: /Users/joel/Work/hoist/docs/feature_gap_analysis.md:91-105 (tail calls/multi-return/varargs gaps), /Users/joel/Work/hoist/docs/cranelift-gap-analysis.md:191-207 (ABI advantages), /Users/joel/Work/hoist/src/backends/aarch64/abi.zig:431-740 (ABI logic). Root cause: incomplete multi-return, tail-call marshaling, varargs wiring, multi-CC coverage. Fix: implement missing ABI behaviors + tests across aarch64/x64. Why: ABI parity with Cranelift and correct interop.
