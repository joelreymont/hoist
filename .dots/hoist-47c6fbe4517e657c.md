---
title: Emit constant pools for large literals
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.404937+02:00"
closed-at: "2026-01-07T10:42:57.220849+02:00"
---

File: src/machinst/buffer.zig extend constant pool support
Need: Track constants during lowering, emit at end or in islands
Implementation: Register large constants with buffer during lowering, check if need island (constants too far), emit island with constants and branch over, fix up constant loads
Dependencies: First emit dot
Estimated: 3 days
Test: Test with many constants requiring island
