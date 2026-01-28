---
title: Implement rotate lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T23:48:44.995283+02:00"
closed-at: "2026-01-05T23:50:50.287303+02:00"
---

File: src/codegen/compile.zig. Opcodes: rotr, rotl. Instructions: ROR (rotate right). rotl = ror with (bitwidth - shift). Binary ops with shift amount. Effort: 30 min.
