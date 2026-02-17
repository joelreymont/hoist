---
title: Handle non-contig phi moves
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T10:38:33.804667+01:00\""
closed-at: "2026-02-17T10:38:33.833793+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

File: /Users/joel/Work/hoist/src/codegen/compile.zig:6633. Cause: resolver assumed contiguous mov_rr; spill loads/stores can interleave. Fix: scan forward from first_insn and collect exactly count mov_rr indices, rewrite/NOP by collected indices. Why: correctly resolve parallel copies in realistic rewritten blocks.
