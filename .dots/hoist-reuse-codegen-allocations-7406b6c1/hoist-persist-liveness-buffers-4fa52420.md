---
title: Persist liveness buffers per context
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.884807+01:00\""
closed-at: "2026-02-17T14:11:44.748466+01:00"
close-reason: "implemented reusable CFG liveness buffers via computeLivenessWithCFGInto + context-persisted aarch64_liveness; validated with 5-run A/B: fib -7.14%, large500 -6.21%, large1000 -6.42%, int -10.20%, vector -8.33% (/tmp/hoist-liveness-reuse-report.md)"
---

Context: src/codegen/compile.zig:6487 and src/regalloc/liveness.zig; cause: liveness allocates transient structures on every compile; fix: introduce reusable liveness workspace in codegen context; deps: Add regalloc state reset reuse; verification: reduced alloc/free counts and stable compile correctness.
