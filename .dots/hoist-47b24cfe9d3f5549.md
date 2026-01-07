---
title: Add istore8 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.769552+02:00"
closed-at: "2026-01-06T08:34:12.815428+02:00"
---

File: src/codegen/compile.zig line ~750. Lower istore8 to STRB instruction. Uses existing strb inst variant at inst.zig:634. Pattern: extract value, get address, emit STRB. ARM64: STRB Wt, [Xn, #offset]. Effort: 20 min.
