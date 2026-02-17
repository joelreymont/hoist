---
title: Array-based unreachable pass
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:31:56.402442+01:00\""
closed-at: "2026-02-17T16:33:46.299373+01:00"
close-reason: "discarded: failed A/B gate (serial batch regression >5%); reverted"
---

src/codegen/compile.zig eliminateUnreachableCode(): replace AutoHashMap worklist/reachable tracking with block-index bool array + queue for lower compile overhead. Validate A/B and keep only if >=5% positive.
