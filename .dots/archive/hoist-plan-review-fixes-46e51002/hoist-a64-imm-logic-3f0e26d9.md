---
title: A64 imm_logic size
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-05T01:25:12.905496+01:00\\\"\""
closed-at: "2026-02-05T18:45:58.260742+01:00"
close-reason: Type annotate imm_logic size
---

src/backends/aarch64/isle_helpers.zig:116; cause: enum literal (.size32/.size64) chosen via runtime if without explicit type -> comptime-only value error in Zig 0.15; fix: type-annotate OperandSize (or Inst.OperandSize) for size variable; test: zig build test
