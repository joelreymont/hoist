---
title: Optimize live-range reconstruction
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.840013+01:00\""
closed-at: "2026-02-17T14:32:58.415813+01:00"
close-reason: live-range reconstruction dense-array path was implemented and benchmarked during dense-vreg work, then discarded under >=5% rule due regressions on small/serial workloads (report /tmp/hoist-dense-vreg-report.md)
---

Context: src/regalloc/liveness.zig:500-620; cause: reconstruction walks hash structures repeatedly; fix: derive ranges from dense arrays indexed by compact vreg ids; deps: Replace live sets with bitsets; verification: range overlap/interference tests still pass.
