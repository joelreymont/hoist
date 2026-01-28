---
title: Frame layout integration testing
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:04.906780+02:00"
closed-at: "2026-01-07T15:37:56.393563+02:00"
---

TESTING not implementation (oracle correction). calculateFrameSize() already exists (abi.zig:936-1004). Test with various slot counts. Verify 16-byte alignment. Test FP/LR and callee-save placement. Test: Multiple frame size scenarios. Phase 1.2, Priority P0
