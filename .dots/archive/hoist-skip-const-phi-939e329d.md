---
title: Skip const-phi when impossible
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:26:21.383172+01:00\""
closed-at: "2026-02-17T16:31:17.055965+01:00"
close-reason: "done: skip const-phi pass when no non-entry block params; A/B win fib +12.50% with gate pass (/tmp/hoist-constphi-ab.md)"
---

src/codegen/compile.zig optimize(): run removeConstantPhis only if some non-entry block has params; otherwise skip pass. Validate A/B and keep only if >=5% positive.
