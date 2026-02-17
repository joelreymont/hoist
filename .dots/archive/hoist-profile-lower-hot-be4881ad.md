---
title: Profile lower hot
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:41:48.904029+01:00\""
closed-at: "2026-02-18T00:01:05.888148+01:00"
close-reason: "completed: control run showed stale parent baseline drift (unchanged tree failed gate on large(100)); switch to fresh same-session baselines before candidate gating"
---

Full context: repeated speculative micro-optimizations are unstable; need direct hotspot evidence for single-thread compile. Capture CPU sample on bench_large and map top symbols to source lines in compile/lower/regalloc, then pick one sub-30min implementation dot tied to measured top stack. Verification: document hypothesis/prediction/falsification/evidence in dot notes; then run tests and perf gate for selected code change.
