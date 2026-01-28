---
title: Add vreg→preg rewriting for Priority 2 load/store instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T11:02:28.077951+02:00"
closed-at: "2026-01-07T11:04:02.734020+02:00"
---

File: src/codegen/compile.zig in emitAArch64WithAllocation()

Priority 2: Essential Load/Store operations (16 instruction types):
- Basic loads: ldr, ldr_reg, ldr_ext, ldr_shifted
- Basic stores: str, str_reg, str_ext, str_shifted
- Byte/halfword loads: ldrb, ldrh, ldrsb, ldrsh, ldrsw
- Byte/halfword stores: strb, strh
- Pair operations: stp (store pair)

Pattern for loads (dst + base):
.ldr => |*i| {
    if (i.dst.toReg().toVReg()) |vreg| { ... }
    if (i.base.toVReg()) |vreg| { ... }
}

Pattern for stores (src + base):
.str => |*i| {
    if (i.src.toVReg()) |vreg| { ... }
    if (i.base.toVReg()) |vreg| { ... }
}

Strategy: Add as tests fail with 'FATAL: Virtual register' panics.
Estimated: 100-150 LOC to add all 16 types
