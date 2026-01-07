---
title: Create trivial allocator structure
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:53.980635+02:00"
closed-at: "2026-01-05T17:01:27.307820+02:00"
---

File: src/regalloc/trivial.zig - Create TrivialAllocator struct with: vreg_to_preg: HashMap(VReg, PReg), next_free_int: u8, next_free_float: u8, allocator: Allocator. Add init()/deinit() methods. No allocation logic yet, just structure. ~30 LOC.
