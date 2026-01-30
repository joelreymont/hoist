---
title: Fix x64 value mapping
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T12:52:49.141586+01:00\\\"\""
closed-at: "2026-01-30T12:53:53.559257+01:00"
close-reason: completed
---

Context: src/generated/x64_lower_generated.zig (iconst/binary/binary_imm64); cause: results allocated with allocVReg not tied to SSA values; fix: use ctx.getValueReg for result values so uses read correct vregs; deps: none; verification: add lowering test + zig build test
