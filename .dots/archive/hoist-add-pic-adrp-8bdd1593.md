---
title: Add PIC ADRP+LDR+BLR calls
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:50.620028+02:00\""
closed-at: "2026-01-23T14:52:22.368823+02:00"
---

In src/backends/aarch64/isle_helpers.zig, implement GOT-based calls for PIC. Emit ADRP+LDR+BLR sequence. Deps: none. Verify: zig build test
