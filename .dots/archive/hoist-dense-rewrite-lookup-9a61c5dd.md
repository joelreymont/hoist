---
title: Dense rewrite lookup
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:25:02.965668+01:00\\\"\""
closed-at: "2026-02-17T22:27:52.388117+01:00"
close-reason: "discarded: failed gate, large(100) regressed +7.02%"
---

Context: src/codegen/compile.zig rewriteInstRegs does hashmap lookups per operand (getPhysReg/getSpillSlot), and rewrite stage is a major single-thread cost on large functions. Cause: repeated hash probes in hot rewrite loop. Fix: build dense vreg->preg/spilled lookup table for large regalloc maps, use it in RegMapper with fallback to maps for small/edge cases. Verify: zig build test -j1 + same-tree A/B bench gate; keep only if >=5% retained gains and no regressions.
