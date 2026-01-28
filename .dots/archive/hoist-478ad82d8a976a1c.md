---
title: "P2.11g-a: Add condition code extractors and converters"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T09:25:18.186148+02:00"
closed-at: "2026-01-04T09:43:04.534383+02:00"
---

File: src/backends/aarch64/isle_helpers.zig - Add extern constructors: float_cc_cmp_zero_to_vec_misc_op, float_cc_cmp_zero_to_vec_misc_op_swap, int_cc_cmp_zero_to_vec_misc_op, int_cc_cmp_zero_to_vec_misc_op_swap. Add extern extractors: fcmp_zero_cond, fcmp_zero_cond_not_eq, icmp_zero_cond, icmp_zero_cond_not_eq. These map condition codes to VecMisc2 ops.
