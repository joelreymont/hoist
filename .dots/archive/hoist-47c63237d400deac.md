---
title: Add operand lowering unit tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T08:13:51.880208+02:00"
closed-at: "2026-01-07T08:16:48.698051+02:00"
---

File: src/backends/aarch64/operand_lowering_test.zig (~150 lines). Test IR Value → VCode Operand conversion. Test: immediate (iconst), register (vreg), memory (stack slot, global). Each test: create IR value → lower → verify operand type/value. Uses lower_operand() directly. No full lowering needed. Pattern from cranelift: test individual helper functions.
