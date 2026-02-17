---
title: Spill scratch dense
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T20:38:18.793192+01:00\""
closed-at: "2026-02-17T21:57:28.914126+01:00"
close-reason: "discarded: prior A/B showed spill-scratch map rewrite regressed key metrics (large100)"
blocks:
  - hoist-dense-lowering-maps-69d2c116
---

Context: src/codegen/compile.zig:658-840 and spill insertion call site 6617. Cause: spill scratch prep builds nested block/vreg hash maps and block lists, adding overhead in spill-heavy functions. Fix: replace nested hash structures with dense per-block bitsets/index arrays and one-pass rewrite metadata. Why: reduce spill insertion overhead and stabilize large-function compile times. Verify: spill-heavy tests + bench-gate A/B, keep only >=5% improvements.
