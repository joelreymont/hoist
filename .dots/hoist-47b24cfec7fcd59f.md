---
title: Add istore32 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.780486+02:00"
closed-at: "2026-01-06T08:34:12.822959+02:00"
---

File: src/codegen/compile.zig line ~770. Lower istore32 to STR Wt instruction. Uses existing str_imm inst variant. Pattern: extract value, get address, emit STR with size32. ARM64: STR Wt, [Xn, #offset]. Effort: 20 min.
