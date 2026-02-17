---
title: Gate alias pass on memory ops
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:57:12.611410+01:00\""
closed-at: "2026-02-17T15:59:15.081885+01:00"
close-reason: "discarded: failed perf gate (large100 +9.84%, large500 +6.31% regressions); reverted"
---

src/codegen/compile.zig optimize(): runAliasAnalysis only when IR contains memory load/store operations; skip for pure arithmetic/vector functions. Validate with bench-gate A/B; keep only if >=5% positive.
