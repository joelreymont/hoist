---
title: "analysis: loops"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:02:25.608437+02:00\""
closed-at: "\"2026-01-01T17:07:51.446935+02:00\""
close-reason: "\"completed: src/ir/loops.zig with Loop (header, blocks, depth, parent), LoopInfo (loop forest, block-to-loop mapping), loop detection via back edges to dominators, worklist algorithm for loop body discovery. All tests pass.\""
blocks:
  - hoist-474fd9fec1463140
---

src/analysis/loops.zig (~600 LOC)

Port from: cranelift/codegen/src/loop_analysis.rs

Natural loop detection:
- Back edges: edge to dominator
- Loop: all nodes that can reach back edge source without going through header

Loop structure:
- header: Block (single entry)
- blocks: []Block (loop body)
- depth: u8 (nesting level)
- parent: ?LoopId

Uses:
- Loop-invariant code motion
- Induction variable analysis
- Register allocation hints (prefer regs for loop values)
