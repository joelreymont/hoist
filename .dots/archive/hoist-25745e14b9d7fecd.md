---
title: Test ISLE arithmetic rules (iadd/isub/imul/idiv)
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T19:26:27.433334+02:00\""
closed-at: "2026-01-08T19:35:05.205692+02:00"
---

File: Create tests/isle_arithmetic.zig. Test iadd i32/i64 (reg+reg, reg+imm), isub (reg+reg, neg), imul (reg+reg), idiv/irem (sdiv/udiv). Verify coverage tracking records aarch64_add_*, aarch64_sub_*, aarch64_mul_*, aarch64_div_*. Phase 2 of ISLE coverage (hoist-47cc3acf72e365f0). 20-30min.
