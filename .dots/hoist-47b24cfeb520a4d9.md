---
title: Add istore16 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.775661+02:00"
closed-at: "2026-01-06T08:34:12.819178+02:00"
---

File: src/codegen/compile.zig line ~760. Lower istore16 to STRH instruction. Uses existing strh inst variant at inst.zig:641. Pattern: extract value, get address, emit STRH. ARM64: STRH Wt, [Xn, #offset]. Effort: 20 min.
