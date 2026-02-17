---
title: Gate range pass by complexity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:04:42.988740+01:00\""
closed-at: "2026-02-17T16:08:45.627000+01:00"
close-reason: "done: gated range optimization by complexity>=160; A/B gains: fib +16.22%, large100 +11.54%, large500 +5.19%, int +12.50%, vector +12.90%, memory +19.23%, mixed +18.75% with no regressions (/tmp/hoist-rangegate-ab.md)"
---

src/codegen/compile.zig optimize(): run range optimization only above a complexity threshold to reduce compile latency on small functions. Validate with bench-gate A/B and tests; keep only if >=5% positive.
