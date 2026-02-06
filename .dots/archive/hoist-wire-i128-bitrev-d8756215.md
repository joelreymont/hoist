---
title: Wire i128 bitrev/bswap lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-07T00:33:35.785229+01:00\\\"\""
closed-at: "2026-02-07T00:35:56.616692+01:00"
close-reason: i128 bitrev/bswap now lower via pair helpers
---

src/backends/aarch64/lower.isle:1685-1720 still routes I128 bitrev/bswap to aarch64_unimplemented (duplicate bswap rule present). Add lower_bitrev128/lower_bswap128 helpers in src/backends/aarch64/isle_helpers.zig, wire both matching rules to helper lowering, keep duplicate bswap rule consistent to avoid ambiguity, add helper tests, run zig build test -j1 --global-cache-dir .zig-global-cache.
