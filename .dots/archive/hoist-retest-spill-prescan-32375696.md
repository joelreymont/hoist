---
title: Retest spill prescan
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T08:29:30.230880+01:00\""
closed-at: "2026-02-18T08:33:11.887749+01:00"
close-reason: "discarded: repeat-9 perf gate regressions"
---

Full context: insertSpillScratch first pass builds block_spill_uses and vreg_use_blocks but never consumes them (TODO only). Remove dead pre-scan and associated allocations; keep only second-pass rewrite. Verify with tests and repeat-9 gate against /tmp/hoist-noopt-peephole-r9.log baseline; retain only if >=5% gains and zero regressions.
