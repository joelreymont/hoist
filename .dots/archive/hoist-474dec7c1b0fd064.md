---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:25.874200+02:00"
closed-at: "2026-01-01T09:05:26.855957+02:00"
close-reason: Replaced with correctly titled task
---

CRITICAL: Either port regalloc2 (~10k LOC Rust) to Zig OR create FFI wrapper. Decision point: Pure Zig vs FFI tradeoff. Pure Zig: port SSA graph coloring allocator. FFI: wrap existing regalloc2. Depends on: VCode (hoist-474deb7f9da39c2f), regs (hoist-474deaeaf67b3c1d). Files: src/regalloc/* or src/ffi/regalloc2.zig. Register allocation is critical - blocks backend work.
