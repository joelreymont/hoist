---
title: Implement register allocation hints
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:41.046142+02:00"
closed-at: "2026-01-07T06:39:36.842900+02:00"
---

File: src/regalloc/linear_scan.zig - Add hint system to guide register allocation toward better choices. Data: HashMap<VReg, PReg> storing preferred physical registers. Sources of hints: 1) Function arguments (already in arg registers), 2) Copy operations (dst prefers src's register), 3) Call arguments (prefer arg registers). Algorithm: In tryAllocateReg(), check hint first before free list. Improves code quality by reducing moves. Performance optimization, not correctness-critical.
