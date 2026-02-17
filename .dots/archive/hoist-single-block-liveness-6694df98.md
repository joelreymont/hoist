---
title: Single-block liveness fast path
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T14:44:58.966195+01:00\\\"\""
closed-at: "2026-02-17T14:50:06.416810+01:00"
close-reason: "Completed: single-block liveness fast path; A/B vs forced CFG path shows >=5% positive gains across key metrics. Report: /tmp/hoist-fastpath-ab.md"
---

Full context: src/codegen/compile.zig always calls computeLivenessWithCFGInto, which pays CFG dataflow/hash-set overhead even for single-block functions used heavily in benchmarks (e.g., bench/compile_large.zig). Cause: no trivial-CFG specialization. Fix: add reusable computeLivenessInto in src/regalloc/liveness.zig and select it when CFG has one block. Proof: zig build bench-gate -Dbench-repeat=5 and keep only if >=5% positive median improvements with no regressions.
