---
title: Add regalloc state reset reuse
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.879174+01:00"
---

Context: src/codegen/pipeline_state.zig:57-65 and src/codegen/context.zig:239-247; cause: regalloc result is always deinitialized between compiles; fix: add resetForReuse and retain backing allocations across compileFunction calls; deps: Add vcode clear-retain path; verification: same outputs with fewer allocator events in sample.
