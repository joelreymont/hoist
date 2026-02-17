---
title: Peephole fast skip
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T18:21:36.853190+01:00\\\"\""
closed-at: "2026-02-17T18:29:03.561730+01:00"
close-reason: discarded (<5% retained gain)
---

Full context: src/codegen/compile.zig:emitAArch64WithAllocation always materializes block_insts and runs peephole iterations even when block has no candidate opcodes. Cause: unnecessary per-block allocation/pass overhead in emit hot path. Fix: add cheap candidate scan + direct emit fast path, reuse scratch block buffer across blocks.
