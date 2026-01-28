---
title: "P2.1: Survey ALL Inst enum variants"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:10:53.589511+02:00"
closed-at: "2026-01-05T20:23:47.632967+02:00"
close-reason: "Complete survey: 219 total variants in inst.zig, only 5 emitted (mov_imm, mov_rr, add_rr, mul_rr, ret/nop), all 5 have complete register rewriting in compile.zig:518-579. Rewriting is 100% complete for MVP."
---

File: src/backends/aarch64/inst.zig - List every enum variant. Check compile.zig emission (which variants emitted) and rewriting (which have rewriting cases). Create checklist: mov_imm ✓, mov_rr ✓, add_rr ✓, mul_rr ✓, ret ✓, <others> ?
