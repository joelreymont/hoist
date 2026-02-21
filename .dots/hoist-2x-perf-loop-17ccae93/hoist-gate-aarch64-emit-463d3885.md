---
title: gate aarch64 emit peephole by optimize flag
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:48:44.081287+01:00\\\"\""
closed-at: "2026-02-21T21:53:41.821381+01:00"
close-reason: "discarded: same-session repeat-9 old-vs-new showed no >=5% retained wins"
---

Context: emitAArch64WithAllocation always runs 3-iteration peephole passes even when target.optimize=false, adding emit-stage CPU in no-opt compile benchmarks. Change: run peephole passes only when ctx.target.optimize is true. Verify: zig build test -j1; repeat-9 compare against /tmp/hoist-2x-loop-base-r9.log; retain only with >=5% positive wins and no regressions.
