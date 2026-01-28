---
title: Design ValueRegs↔Value bridge for I128
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T15:45:39.209977+02:00"
closed-at: "2026-01-03T15:51:15.763905+02:00"
close-reason: "Investigation revealed the bridge already exists! LowerCtx.value_regs (isle_ctx.zig:48) maps Value→ValueRegs(VReg). getValueRegs() auto-allocates 1 or 2 VRegs based on type. No complex design needed - just add ISLE glue."
---

Files: src/codegen/isle_ctx.zig:48 (value_regs HashMap), src/codegen/lower_helpers.zig:200 (splitI128). Problem: iconcat PRODUCES an I128 IR Value but internally uses ValueRegs(VReg). How to: (1) Store Value→ValueRegs mapping when lowering iconcat, (2) Retrieve ValueRegs when lowering isplit or users of iconcat result, (3) Handle case where IR value used both as I128 and as split parts. Design on paper first: data flow diagram, API signatures, edge cases (error paths, ABI requirements for register pairs). Output: design doc with concrete Zig function signatures and ISLE rule patterns. Depends: investigation dot.
