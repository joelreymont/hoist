---
title: Track regalloc2 operands by inst
status: open
priority: 2
issue-type: task
created-at: "2026-02-06T00:33:40.603521+01:00"
---

src/machinst/regalloc2/api.zig:12 and src/backends/aarch64/regalloc_bridge.zig:42. Cause: getOperands() currently ignores instruction index, collapsing all operands and corrupting liveness precision. Fix: add per-instruction operand storage/API and wire bridge to add operands with inst index. Dependencies: stage regalloc parity dot. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
