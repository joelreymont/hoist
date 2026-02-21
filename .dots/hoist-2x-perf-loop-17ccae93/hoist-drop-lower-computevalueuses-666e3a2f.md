---
title: drop lower computeValueUses call
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-21T21:34:15.483527+01:00\\\"\""
closed-at: "2026-02-21T21:38:41.268918+01:00"
close-reason: "discarded: same-session old-vs-new repeat-9 regressed large(1000) and had no >=5% retained wins"
---

Context: src/machinst/lower.zig lowerFunctionWithFeatures unconditionally runs ctx.computeValueUses() before lowering; rg shows value_uses state is not consumed by backends in active pipeline. Hypothesis: skip this pass in hot path to cut lower-stage compile time. Verify: zig build test -j1, bench-log repeat-9, bench-compare vs /tmp/hoist-2x-loop-base-r9.log with min-positive-pct=5 and no regressions; keep only if gate passes.
