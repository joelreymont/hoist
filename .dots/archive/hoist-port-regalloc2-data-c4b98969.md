---
title: Port regalloc2 data structures
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:49.954421+02:00\""
closed-at: "2026-01-26T08:52:58.079827+01:00"
---

Create src/regalloc/regalloc2.zig with core data structures: VReg, PReg, Operand, Allocation, InstRange. Use Zig idioms (ArrayList, HashMap). Deps: none. Verify: zig build test
