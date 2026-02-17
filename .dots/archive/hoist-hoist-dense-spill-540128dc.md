---
title: hoist-dense-spill-slot
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T08:51:09.098992+01:00\\\"\""
closed-at: "2026-02-18T08:56:12.500904+01:00"
close-reason: "completed: immediate repeat-9 parent-vs-candidate A/B passed with >=5% wins on fib, large(100/500/1000/5000), mixed; zero regressions"
---

src/codegen/compile.zig insertSpillScratch calls RegAllocResult.getSpillSlot hash lookup for every operand use/def in hot rewrite loop; build a dense spill slot side table once per function and use direct indexed lookups to cut rewrite overhead, then gate with immediate repeat-9 parent-vs-candidate A/B
