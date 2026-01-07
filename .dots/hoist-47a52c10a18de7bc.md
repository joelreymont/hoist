---
title: Add getAllocation() lookup to trivial allocator
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:54.727322+02:00"
closed-at: "2026-01-05T17:01:27.315310+02:00"
---

File: src/regalloc/trivial.zig - Add 'pub fn getAllocation(self: *const Self, vreg: VReg) ?PReg' that looks up vreg in vreg_to_preg map. Returns null if not allocated yet. Used during emission to rewrite vregs. ~3 LOC.
