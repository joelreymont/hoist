---
title: Add MOV literal pool fallback
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:06:15.815248+02:00\""
closed-at: "2026-01-24T00:31:23.711668+02:00"
---

Files: src/backends/aarch64/legalize.zig:140-157
What: When constant needs 4+ MOVK chunks, use literal pool instead
Currently: Only handles up to 3 chunks
Fix: Add check for chunk count, emit LDR from constant pool
Verification: Test large constants like 0xDEADBEEF12345678
