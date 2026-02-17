---
title: hoist-tune-spill-reserve
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:31:33.389413+01:00\\\"\""
closed-at: "2026-02-18T09:34:08.372561+01:00"
close-reason: "discarded: no broad retained gains; large-metric regressions outweighed isolated mixed gain"
---

src/codegen/compile.zig adjust insertSpillScratch reserve heuristic from fixed 1.5x old_insn_len to spill-count-aware sizing using result.vreg_to_spill.count() so large spill-heavy functions avoid realloc churn; validate with immediate repeat-9 A/B
