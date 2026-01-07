---
title: Add MOV+MUL pattern for imul_imm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.836065+02:00"
closed-at: "2026-01-06T08:55:30.615770+02:00"
---

File: lower.isle. Create helper to materialize immediate in temp register then multiply. Add aarch64_imul_imm decl that emits MOV temp, #imm + MUL dst, src, temp. ARM64: MOV+MUL. Effort: 20 min.
