---
title: Wire i128 extend lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-07T00:25:31.963472+01:00\\\"\""
closed-at: "2026-02-07T00:30:03.719918+01:00"
close-reason: sextend/uextend i128 now lower via pair helpers
---

src/backends/aarch64/lower.isle:776-816 currently lowers I128 sextend/uextend to aarch64_unimplemented. Implement proper ValueRegs lowering helpers in src/backends/aarch64/isle_helpers.zig and wire ISLE declarations/rules; add focused lowering tests; run zig build test -j1 --global-cache-dir .zig-global-cache. Depends on completed i128 pair infrastructure (lower_iadd128 etc). Est: 30m
