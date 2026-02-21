---
title: single-block liveness monotonic end update
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-21T21:28:20.061819+01:00\\\"\""
closed-at: "2026-02-21T21:33:30.574858+01:00"
close-reason: "discarded: same-session old-vs-new repeat-9 showed no >=5% retained wins"
---

Context: src/regalloc/liveness.zig: computeLivenessInto scans instructions in increasing inst_idx; noteRangeUse currently does min/max on existing ranges each operand. Hypothesis: replace existing-range min/max with direct end update (start fixed on first sight) to cut hot-path ALU/branch overhead in single-thread compile without semantic change. Verify: zig build test -j1; bench-log repeat-9; bench-compare vs /tmp/hoist-2x-loop-base-r9.log with min-positive-pct=5 and no regressions; keep only if gate passes.
