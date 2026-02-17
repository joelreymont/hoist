---
title: Hoist retest dead spill scan
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:57:02.187999+01:00\\\"\""
closed-at: "2026-02-17T16:59:53.137903+01:00"
close-reason: "discarded (same-tree A/B fail: large100 regression +8.13%)"
---

Full context: src/codegen/compile.zig insertSpillScratch has an unused pre-scan over all blocks. Prior gate run against stale baseline showed sub-5 gains. Cause: benchmark drift can hide isolated wins. Fix: run same-tree A/B (before/after logs in /tmp) with only this patch toggled; keep only if >=5% positive medians and no meaningful regressions.
