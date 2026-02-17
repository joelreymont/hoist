---
title: Gate egraph by complexity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.585616+01:00\""
closed-at: "2026-02-17T13:28:35.977638+01:00"
close-reason: "completed egraph complexity gating epic: O(1) function complexity heuristic, threshold-gated egraph execution, configurable threshold through context/target API, and regression tests for boundary behavior; validated by full tests plus 5-run perf report /tmp/hoist-egraph-option-report.md with no >5% regressions and multi-metric improvements"
---

Context: src/codegen/compile.zig:1014-1017, 1176-1253; cause: egraph optimization runs for small/simple functions where overhead dominates; fix: complexity threshold and opt-level-aware gating for egraph pass; deps: Wire release benchmark mode; verification: small-function compile latency drops with unchanged correctness tests.
