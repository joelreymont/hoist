---
title: Add spill slot compression and reuse
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T11:46:25.578614+02:00"
---

File: src/regalloc/linear_scan.zig. Track which vregs use which spill slots. Reuse slots when live ranges don't overlap. Add property test verifying no overlap. Dependencies: basic spill working. Effort: <30min
