---
title: Wire multi-return
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.799253+01:00"
blocks:
  - hoist-fix-impure-constructor-191bc4c5
---

Context: src/ir/signature.zig:203, src/machinst/abi.zig:199; cause: multi-return signatures not lowered to multiple return regs in ABI/emit; fix: extend ABISignature return assignment and AArch64 return lowering to handle >1 return; deps: tuple/multi-return ISLE support; verification: new ABI tests + e2e JIT test returning 2 values.
