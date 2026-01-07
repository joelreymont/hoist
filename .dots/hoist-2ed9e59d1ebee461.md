---
title: Create JumpTable data structure
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:29:20.474340+02:00"
---

File: src/machinst/buffer.zig or new jump_table.zig - Define JumpTable struct to hold table of branch targets. Fields: targets:ArrayList(Block), default:Block, alignment:u32. Methods: addTarget, getOffset, emit. This is the core data structure for br_table. Depends on hoist-47cc378311ab76aa parent.
