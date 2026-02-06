---
title: Wire i128 imul lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:49:15.680624+01:00\""
closed-at: "2026-02-07T00:52:22.880333+01:00"
close-reason: Completed
---

src/backends/aarch64/lower.isle:548 currently lowers imul  to aarch64_unimplemented. Implement lower_imul128 helper in src/backends/aarch64/isle_helpers.zig using mul/umulh/madd sequence and wire ISLE rule via emit_regs; add helper regression test; run zig build test -j1 --global-cache-dir .zig-global-cache.
