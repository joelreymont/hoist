---
title: Skip noopt peephole
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T08:19:55.052681+01:00\""
closed-at: "2026-02-18T08:24:13.200181+01:00"
close-reason: "completed: repeat9 A/B stable; large100 +12.00%, large500 +7.07%, zero gate regressions"
---

Full context: emitAArch64WithAllocation runs block-level peephole passes even when target.optimize=false (bench path uses optimization(false)). Hypothesis: skipping peephole entirely on no-opt path reduces emit stage significantly without semantic change. Fix: guard peephole pass in emitAArch64WithAllocation by ctx.target.optimize. Verify: tests + repeat-9 fresh baseline gate; keep only if >=5% retained gains and no regressions.
