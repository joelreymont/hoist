---
title: Dense block map
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T18:21:36.868871+01:00\""
closed-at: "2026-02-17T18:29:03.568198+01:00"
close-reason: discarded (perf regressions)
---

Full context: src/codegen/compile.zig lowerAArch64 uses AutoHashMap block lookups for CFG successor mapping and per-inst terminator branch targets. Cause: hash lookup overhead in hot lowering loops. Fix: replace with dense block-index arrays for layout-order mapping and successor resolution.
