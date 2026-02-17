---
title: hoist-dense-origin-lookup
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:07:16.455998+01:00\\\"\""
closed-at: "2026-02-18T09:10:58.365524+01:00"
close-reason: "discarded: no >=5% retained gains in immediate repeat-9 A/B"
---

src/codegen/compile.zig insertSpillScratch still does hash lookup on vreg_origins for each spilled use; build dense origin side table once and replace per-use map lookups with direct indexed access, then gate via immediate repeat-9 parent-vs-candidate A/B
