---
title: Wire i128 bitcast no-op lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-07T00:36:52.765512+01:00\\\"\""
closed-at: "2026-02-07T00:46:50.888192+01:00"
close-reason: Completed
---

src/backends/aarch64/lower.isle:3240-3242 has I128->I128 bitcast as aarch64_unimplemented. Route to emit_regs(put_in_regs x) so lowering preserves pair regs without unimplemented trap. Add lowering regression in src/backends/aarch64/lower_test.zig to ensure i128 bitcast emits without unimplemented fallback. Run zig build test -j1 --global-cache-dir .zig-global-cache.
