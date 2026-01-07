---
title: Insert spill and reload instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.360425+02:00"
closed-at: "2026-01-07T10:42:57.196043+02:00"
---

File: src/machinst/regalloc.zig add applyEdits()
Need: Process regalloc2::Output.edits, insert spill/reload instructions
Implementation: Iterate regalloc.edits (sorted by instruction index), insert store/load instructions
Dependencies: Previous regalloc dot
Estimated: 2 days
Test: Create VCode needing spills, verify inserts correct
