---
title: Fix dce.zig enum literal error
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:15:42.143115+02:00"
closed-at: "2026-01-04T15:16:12.203954+02:00"
---

File: src/codegen/opts/dce.zig:87 - Error: expected type '*const ir.instruction_data.InstructionData', found '@Type(.enum_literal)'. Need to check what's being passed incorrectly.
