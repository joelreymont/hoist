---
title: Add regalloc state reset reuse
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.879174+01:00\\\"\""
closed-at: "2026-02-17T14:03:11.291619+01:00"
close-reason: "implemented regalloc result/state reuse across compileFunction via resetForReuse + allocateInto; benchmarked with 5-run A/B: large100 -5.50%, large500 -7.52%, large1000 -6.32%, serial batch -5.66% (report /tmp/hoist-regalloc-reuse-report.md)"
---

Context: src/codegen/pipeline_state.zig:57-65 and src/codegen/context.zig:239-247; cause: regalloc result is always deinitialized between compiles; fix: add resetForReuse and retain backing allocations across compileFunction calls; deps: Add vcode clear-retain path; verification: same outputs with fewer allocator events in sample.
