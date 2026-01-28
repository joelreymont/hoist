---
title: Stack slot allocation algorithm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:05.294656+02:00"
closed-at: "2026-01-07T16:25:06.959552+02:00"
---

Add StackSlotData tracking to Function (may already exist). Implement slot allocation on demand. Handle different sizes (1, 2, 4, 8, 16 bytes). Reserve space in frame layout. Test: Allocate 20 slots of various sizes. Phase 1.3, Priority P0
