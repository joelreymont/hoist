---
title: Handle i128 ABI slots
status: closed
priority: 1
issue-type: task
created-at: "2026-01-14T13:03:03.725096+02:00"
---

Files: src/machinst/abi.zig:270, src/machinst/abi.zig:426. Root cause: ABIMachineSpec computeArgLocs/computeRetLocs treats i128 as single int slot; AAPCS64 requires X0:X1 pairs with 16-byte alignment. Fix: special-case Type.i128 to allocate two slots in int regs (or aligned stack), use Type.i64 per slot; update ret handling similarly. Verify: machinst.abi AAPCS64 i128 arg/ret tests pass.
closed-at: "2026-01-23T08:48:21+02:00"
close-reason: already handled at 361,473
