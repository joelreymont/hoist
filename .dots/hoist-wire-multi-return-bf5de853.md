---
title: Wire multi-return
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T23:31:19.322998+01:00"
---

Context: src/ir/signature.zig:203, src/machinst/abi.zig:199; cause: multi-return signatures not lowered to multiple return regs in ABI/emit; fix: extend ABISignature return assignment and AArch64 return lowering to handle >1 return; deps: tuple/multi-return ISLE support; verification: new ABI tests + e2e JIT test returning 2 values.
