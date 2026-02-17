---
title: Skip unused complexity calc
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:11:38.164951+01:00\""
closed-at: "2026-02-17T16:13:35.434243+01:00"
close-reason: "discarded: failed A/B gate; regressions in fib/int/mixed; reverted"
---

src/codegen/compile.zig optimize(): avoid estimateFunctionComplexity() when target.optimize is false; current code computes it unconditionally before early return. Validate A/B and keep only if >=5% positive.
