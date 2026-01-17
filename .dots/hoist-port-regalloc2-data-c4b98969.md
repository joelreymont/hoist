---
title: Port regalloc2 data structures
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:49.954421+02:00"
---

Create src/regalloc/regalloc2.zig with core data structures: VReg, PReg, Operand, Allocation, InstRange. Use Zig idioms (ArrayList, HashMap). Deps: none. Verify: zig build test
