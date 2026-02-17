---
title: hoist-retest-spill-prescan-ab
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T08:44:56.403859+01:00\\\"\""
closed-at: "2026-02-18T08:50:04.239966+01:00"
close-reason: "completed: immediate repeat-9 parent-vs-candidate A/B passed with >=5% wins on large(100/500/1000/5000), int, mixed; zero regressions"
---

src/codegen/compile.zig insertSpillScratch first pass builds block_spill_uses/vreg_use_blocks but second pass never consumes them; re-test removal with immediate parent-vs-candidate repeat-9 A/B to eliminate stale-baseline drift and retain only on >=5% wins with no regressions
