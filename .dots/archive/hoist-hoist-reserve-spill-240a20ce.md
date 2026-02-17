---
title: hoist-reserve-spill-rewrite
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:27:00.118717+01:00\\\"\""
closed-at: "2026-02-18T09:31:09.133187+01:00"
close-reason: "completed: immediate repeat-9 A/B showed qualifying gain on large(100) with zero gate regressions"
---

src/codegen/compile.zig insertSpillScratch builds new_insns from empty and may reallocate heavily on spill-heavy large functions; reserve capacity up front from old_insn_len to reduce growth churn, then gate with immediate repeat-9 A/B
