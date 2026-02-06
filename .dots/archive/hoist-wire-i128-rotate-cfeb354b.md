---
title: Wire i128 rotate lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:52:57.291299+01:00\""
closed-at: "2026-02-07T00:56:00.936098+01:00"
close-reason: Completed
---

src/backends/aarch64/lower.isle:1194-1215 lowers rotr/rotl  to aarch64_unimplemented. Add lower_rotr128/lower_rotl128 helpers in src/backends/aarch64/isle_helpers.zig using variable shifts and csel swap on bit6; wire rules via emit_regs; add helper tests; run zig build test -j1 --global-cache-dir .zig-global-cache.
