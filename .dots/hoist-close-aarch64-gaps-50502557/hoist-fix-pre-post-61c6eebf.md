---
title: Fix pre/post imm enc
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-14T14:14:17.346991+02:00\\\"\""
closed-at: "2026-01-14T14:19:10.479698+02:00"
close-reason: encoded size/opc bits for pre/post and updated tests
---

Files: src/backends/aarch64/emit.zig:2403,2428,2453,2478. Root cause: pre/post LDR/STR use sf bit and wrong opc bit (bit21 set), size bits not encoded. Fix: add helper to encode size|111|0|00|opc|imm9|index|Rn|Rt and use for emitLdrPre/Post/StrPre/Post. Why: match ARM ARM and assembler encodings for indexed loads/stores.
