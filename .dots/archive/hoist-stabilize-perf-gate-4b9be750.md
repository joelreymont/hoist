---
title: Stabilize perf gate baseline
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:36:15.554987+01:00\""
closed-at: "2026-02-17T15:38:19.337093+01:00"
close-reason: "done: bench-gate now uses persistent baseline; refresh via baseline-log; verified pass with repeat=7 and 0 regressions (/tmp/hoist-bench-report.md)"
---

build.zig/tools/perf_gate.zig: bench-gate currently regenerates both baseline/current each run, causing order bias and false regressions. Fix by using persistent baseline file for gate, only generating current in bench-gate, and add explicit baseline refresh step. Proof: bench-gate should pass for unchanged tree and still fail on real regressions.
