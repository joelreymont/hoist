---
title: Fix emit.zig root imports - replace with relative paths
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:51.365853+02:00"
closed-at: "2026-01-05T17:01:27.286367+02:00"
---

File: src/backends/aarch64/emit.zig:4-14 - Replace 'const root = @import("root")' with relative imports. Change root.aarch64_inst.* to inst_mod.* where inst_mod = @import("inst.zig"). Change root.buffer to @import("../../machinst/buffer.zig"). This fixes test compilation failures in e2e_loops.zig, e2e_branches.zig, e2e_jit.zig. CRITICAL: Must preserve all type imports (Inst, OperandSize, FpuOperandSize, VectorSize, VecElemSize, BarrierOption, CondCode, Reg, PReg). Test with 'zig build test' to verify all 396 tests still pass.
