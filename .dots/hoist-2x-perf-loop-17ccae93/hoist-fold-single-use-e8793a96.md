---
title: fold single-use iconst into iadd immediate
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:54:43.871747+01:00\\\"\""
closed-at: "2026-02-21T22:16:51.230020+01:00"
close-reason: "completed: size-gated single-use iconst->iadd immediate fold retained with repeat-9 old-vs-new gate pass"
---

Context: AArch64 lowering currently emits mov_imm for iconst and add_rr for iadd, creating extra vregs/instructions. Implement pre-lowering analysis to mark single-use iconst consumed by integer iadd with encodable +/-12-bit immediate; skip iconst emission and emit add_imm/sub_imm in iadd lowering. Goal: reduce lower/regalloc/rewrite/emit cost on large no-opt benchmarks. Verify with repeat-9 gate and keep only if >=5% wins with no regressions.
