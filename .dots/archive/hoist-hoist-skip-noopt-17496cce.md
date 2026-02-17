---
title: hoist-skip-noopt-peephole-v2
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:02:45.836069+01:00\\\"\""
closed-at: "2026-02-18T09:06:27.863786+01:00"
close-reason: "discarded: no >=5% retained gains in immediate repeat-9 A/B"
---

src/codegen/compile.zig emitAArch64WithAllocation currently runs peephole passes unconditionally; gate peephole loop on target.optimize so no-opt compile path skips pair/dead-load passes entirely, then verify with immediate repeat-9 parent-vs-candidate A/B
