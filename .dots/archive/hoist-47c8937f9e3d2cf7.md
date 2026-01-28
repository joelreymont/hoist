---
title: Add vreg→preg rewriting for Priority 3 branch instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T11:04:13.909582+02:00"
closed-at: "2026-01-07T11:05:23.425566+02:00"
---

File: src/codegen/compile.zig in emitAArch64WithAllocation()

Priority 3: Essential branch/control flow operations (6 instruction types):
- Unconditional: br (branch register), bl (branch link)
- Indirect: blr (branch link register) 
- Conditional: b_cond (branch if condition)
- Compare & branch: cbz (compare and branch if zero), cbnz (compare and branch if non-zero)
- Test bit & branch: tbz (test bit and branch if zero), tbnz (test bit and branch if non-zero)

Pattern for register branches:
.br => |*i| {
    if (i.target.toVReg()) |vreg| { ... }
}

Pattern for compare branches:
.cbz => |*i| {
    if (i.reg.toVReg()) |vreg| { ... }
}

Note: b_cond has no register operands (uses condition flags + label)
Note: bl has no register operands (uses immediate offset)

Estimated: 50-80 LOC to add all 6-8 types
