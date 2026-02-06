---
title: Add isplit fallback for non-iconcat i128
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:29:43.096808+01:00\""
closed-at: "2026-02-06T21:31:37.885780+01:00"
close-reason: Handled non-iconcat i128 defs in isplit and added regression
---

src/backends/aarch64/isle_helpers.zig:2747 currently only supports iconcat in aarch64_isplit and returns Unimplemented for block params/other i128 defs. Implement pinned-vreg pair fallback mirroring put_in_regs and add regression test near existing put_in_regs tests. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
