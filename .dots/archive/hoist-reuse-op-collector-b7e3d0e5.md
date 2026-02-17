---
title: Reuse op collector
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:43:14.862978+01:00\""
closed-at: "2026-02-17T23:46:42.246612+01:00"
close-reason: "discarded: gate regression (serial batch +5.67%)"
---

Full context: src/codegen/compile.zig insertSpillScratch does OperandCollector.init/deinit for every instruction in both passes, causing repeated allocations in hot regalloc/rewrite path. Fix: allocate one collector per pass (or per block) and clearRetainingCapacity() each instruction. Keep semantics identical. Verify: zig build test + parent-vs-current bench gate + rerun stability; retain only if >=5% positive gains and no regressions.
