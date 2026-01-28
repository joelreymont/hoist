---
title: Implement integer comparison lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T23:44:41.778681+02:00"
closed-at: "2026-01-05T23:46:10.006489+02:00"
---

File: src/codegen/compile.zig. Opcode: icmp. Instruction: CMP (set flags) + CSET (materialize bool). Similar to fcmp but for integers. IntCC conditions: eq, ne, slt, sle, sgt, sge, ult, ule, ugt, uge. Effort: 30 min.
