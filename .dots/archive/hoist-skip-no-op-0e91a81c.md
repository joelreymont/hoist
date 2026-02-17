---
title: Skip no-op single-block opts
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:18:28.011384+01:00\""
closed-at: "2026-02-17T16:22:11.004005+01:00"
close-reason: "done: skipped unreachable/const-phi passes for single-block functions; A/B wins include large100 +5.93%, int +31.03%, vector +31.03%, memory +35.00%, mixed +32.00% (/tmp/hoist-singleopt-ab2.md)"
---

src/codegen/compile.zig optimize(): for single-block functions, skip eliminateUnreachableCode and removeConstantPhis since they are no-op; keep legality/cfg/domtree/other needed passes. Validate A/B and keep only if >=5% positive.
