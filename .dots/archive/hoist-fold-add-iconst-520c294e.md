---
title: Fold add iconst
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:49:03.354522+01:00\""
closed-at: "2026-02-17T23:54:58.796411+01:00"
close-reason: "discarded: severe gate regressions across large and micro benchmarks"
---

Full context: large compile benchmark emits iconst + iadd chains; lowering currently materializes iconst into mov_imm and then add_rr, inflating instruction count and downstream regalloc/rewrite cost. Fix: in AArch64 lowering, fold iadd with iconst operand into add_imm/sub_imm when encodable; then run a dead mov_imm elimination pass post-lowering to remove now-unused materializations. Verify with zig build test and parent-vs-current gate + rerun; keep only if >=5% retained gain and zero regressions.
