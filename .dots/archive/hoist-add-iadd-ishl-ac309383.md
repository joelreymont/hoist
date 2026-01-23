---
title: Add iadd_ishl fold patterns
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:04:57.078858+02:00\""
closed-at: "2026-01-24T00:25:48.547622+02:00"
---

Files: src/generated/aarch64_lower.isle
What: Add patterns to fold (iadd x (ishl y k)) into ADD with LSL operand
Purpose: Single instruction for address calculations like base + (index << scale)
Pattern: Match iadd where second operand is ishl with constant
Verification: Test array indexing patterns
