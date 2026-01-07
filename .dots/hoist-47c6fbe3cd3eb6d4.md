---
title: Implement VCode.emit() loop over blocks and instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.371086+02:00"
closed-at: "2026-01-07T10:42:57.205818+02:00"
---

File: src/machinst/vcode.zig add emit() method
Implementation: Create MachBuffer, reserve labels for blocks, emit each block (bind label, emit instructions via inst.emit), handle prologue/epilogue
Dependencies: All regalloc dots
Estimated: 2 days
Test: Emit simple VCode, verify structure
