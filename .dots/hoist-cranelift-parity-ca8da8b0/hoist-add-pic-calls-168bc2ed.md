---
title: Add PIC calls
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.583034+02:00\""
closed-at: "2026-01-23T14:51:17.509099+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3453-3509, src/backends/aarch64/emit.zig:13349-13396
Root cause: calls always use direct BL without GOT/PLT.
Fix: add PIC call lowering (ADRP+LDR+BLR) with relocations.
Why: position-independent code support.
Deps: Fix extname call.
Verify: relocation tests.
