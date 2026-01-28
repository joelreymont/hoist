---
title: Add block parameter tracking to VCode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:09:20.934743+02:00"
closed-at: "2026-01-07T09:19:50.657598+02:00"
---

File: src/machinst/vcode.zig lines 20-35 (VCodeBlock)
Currently: VCodeBlock has params: []const VReg field but unused
Need: Track block parameters properly
Implementation:
1. VCodeBuilder.startBlock() - accept block params
2. Store in VCodeBlock.params
3. Lower.zig - pass block params when starting blocks
Dependencies: hoist-47c6f69cbdf3aabc
Estimated: 4 hours
Test: Create block with params, verify stored
