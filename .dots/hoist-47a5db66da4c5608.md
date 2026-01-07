---
title: Fix SSA dominance frontier calculation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T17:38:56.390747+02:00"
closed-at: "2026-01-05T18:06:09.455306+02:00"
---

Files: src/ir/ssa_tests.zig:222, src/ir/domtree.zig - Two SSA tests failing: 'dominance frontier for diamond CFG' expects \!dominates(b2,b3) but gets opposite, and 'dominance frontier for loop' crashes. Diamond CFG: b0->(b1,b2), b1->b3, b2->b3. b2 should NOT dominate b3 since you can reach b3 via b1. Check DominatorTree.compute() algorithm, verify it correctly implements Lengauer-Tarjan or Cooper-Harvey-Kennedy algorithm.
