---
title: "P2.11: Missing vector operations"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:12:00.066695+02:00"
closed-at: "2026-01-04T14:25:53.610819+02:00"
---

File: src/backends/aarch64/lower.isle - Add remaining ~90 vector operation patterns from Cranelift. Need comprehensive gap analysis comparing Cranelift's vector patterns to Hoist's implementation across all vector opcodes (arithmetic, bitwise, shifts, extends, narrows, etc.).
