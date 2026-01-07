---
title: Implement large stack frame handling
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:38.024334+02:00"
closed-at: "2026-01-06T11:05:35.593139+02:00"
---

File: src/codegen/stack_frame_aarch64.zig. Frames >4KB require stack probes (see overflow protection dot). Frames >256KB may need multiple SUB instructions (immediate limited to 12 bits). Frame pointer (X29) required if frame dynamic or >512 bytes (for unwinding). Dependencies: stack slot allocation. Effort: 1 day.
