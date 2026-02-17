---
title: Gate egraph on complexity threshold
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.901636+01:00\\\"\""
closed-at: "2026-02-17T13:24:43.413333+01:00"
close-reason: "implemented O(1) complexity scoring plus egraph threshold gate in src/codegen/compile.zig; validated with zig build test and 5-run perf comparison (/tmp/hoist-egraph-gate-report.md): fib -19.30%, large5000 -5.14%, int -22.73%, vector -13.56%, memory -10.64%, mixed -12.73%, zero >5% regressions"
---

Context: src/codegen/compile.zig:1014-1017; cause: egraph cost outweighs benefit on tiny functions; fix: run egraph only when complexity and opt-level thresholds are met; deps: Add function complexity score; verification: small-benchmark optimize time drops while correctness tests pass.
