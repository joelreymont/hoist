---
title: Trim vreg origins
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:32:53.941319+01:00\""
closed-at: "2026-02-17T23:37:19.025919+01:00"
close-reason: "discarded: unstable; rerun gate failed (fib/large100/serial/micro regressions)"
---

Full context: src/codegen/compile.zig records VRegOrigin.forBinop at multiple lowering sites, but insertSpillScratch only rematerializes .iconst/.f32const/.f64const from vreg_origins (src/codegen/compile.zig:747-768). Cause: unnecessary hashmap puts in lowering hot path for non-const values. Fix: stop recording non-const origins and simplify VRegOrigin shape accordingly. Verify with zig build test and parent-vs-current bench gate; keep only if >=5% retained improvement, no regressions.
