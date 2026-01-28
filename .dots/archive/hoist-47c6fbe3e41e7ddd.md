---
title: Compute stack frame layout before emission
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.376937+02:00"
closed-at: "2026-01-07T10:42:57.210693+02:00"
---

File: src/backends/aarch64/abi.zig use existing computeFrameLayout()
Currently: Frame layout methods exist but not called
Need: Call before emission, integrate with regalloc spillslots
Implementation: Get spillslot count from regalloc2::Output, get clobbers, call abi.computeFrameLayout(spillslots, clobbers, calls_functions)
Dependencies: Previous regalloc dot
Estimated: 1 day
Test: Verify frame size calculated correctly
