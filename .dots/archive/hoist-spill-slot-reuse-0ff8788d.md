---
title: Spill slot reuse
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:26:48.197518+01:00\""
closed-at: "2026-02-01T14:28:24.111185+01:00"
close-reason: completed
---

src/regalloc/linear_scan.zig:506 cause: free_slots.pop uses orelse unreachable; fix: return error.SpillSlotEmpty and add reuse test; why: avoid error masking, enforce spill slot invariants.
