---
title: Persist liveness buffers per context
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.884807+01:00"
---

Context: src/codegen/compile.zig:6487 and src/regalloc/liveness.zig; cause: liveness allocates transient structures on every compile; fix: introduce reusable liveness workspace in codegen context; deps: Add regalloc state reset reuse; verification: reduced alloc/free counts and stable compile correctness.
