---
title: hoist-fold-iadd-singleuse
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T10:29:17.821882+01:00\""
closed-at: "2026-02-18T10:29:24.251131+01:00"
close-reason: "discarded: repeat-9 gate regressions on fib/int/vector/mixed"
---

src/codegen/compile.zig precompute single-use iconst values and fold iadd to add_imm/sub_imm while skipping iconst emission; measured strong large-function gains but regressed fib/int/vector/mixed micro suites above gate threshold in repeat-9 A/B; discard
