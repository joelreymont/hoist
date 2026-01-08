---
title: Create InterferenceGraph type
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:20:43.220255+02:00\""
closed-at: "2026-01-08T21:27:28.079626+02:00"
---

File: src/regalloc/interference.zig (new). Define InterferenceGraph struct with: edges: HashMap(VReg, BitSet), allocator. Two vregs interfere if live ranges overlap. Add init/deinit, interferes(v1, v2) query. ~10 min.
