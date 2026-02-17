---
title: Retest vreg trim
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T00:05:03.463132+01:00\""
closed-at: "2026-02-18T00:12:48.453536+01:00"
close-reason: "completed: repeat9 parent-now A/B shows >5% gains on large500/1000/5000 with zero gate regressions"
---

Full context: prior non-const vreg_origin-tracking removal showed strong first-pass gains but was rejected under stale baseline. Reapply change and gate against fresh baseline /tmp/hoist-control-current.log with stability rerun. Keep only if sustained >=5% gains and no regressions.
