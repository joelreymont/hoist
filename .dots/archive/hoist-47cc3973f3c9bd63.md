---
title: return_call lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:25:23.064794+02:00\""
closed-at: "2026-01-07T23:35:55.056068+02:00"
---

Emit epilogue (restore FP, LR). Generate B (branch) instead of BL. No LR save needed. Handle argument marshaling. Test: Tail recursive factorial. File: isle_impl.zig:1149. Phase 3.3, Priority P1
