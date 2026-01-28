---
title: regalloc2 decision
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.696318+02:00\""
closed-at: "\"2026-01-01T16:35:13.518771+02:00\""
close-reason: "\"Implemented simple LinearScanAllocator (~203 LOC) as bootstrap solution. Supports per-class register pools, allocation/freeing, and Allocation result struct for reg/spill mappings. All 9 tests pass. Decision: linear scan for now, upgrade to regalloc2 (FFI or port) once backend validates. Total: ~11k LOC\""
blocks:
  - hoist-474fd4a2b20bac04
---

CRITICAL DECISION POINT

Options:
1. Port regalloc2 (~10k LOC) to Zig
2. FFI wrapper to call Rust regalloc2
3. Simple linear scan allocator (worse code quality)

regalloc2 features:
- SSA-based graph coloring
- Live range splitting
- Optimal spill placement
- Move coalescing

Recommendation: Start with FFI, port later
- FFI lets us validate everything else works
- Porting is significant effort
- Can be done in parallel with backend work

Interface needed:
- Input: VCode with virtual regs
- Output: VCode with physical regs + spills

BLOCKS ALL BACKEND TESTING
