---
title: Reuse codegen allocations
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.571945+01:00"
---

Context: src/context.zig:95, src/codegen/context.zig:239-296, src/codegen/pipeline_state.zig:42-47; cause: compile loop repeatedly deinit/reinit state causing mmap/munmap churn; fix: clear-retain reuse for vcode/regalloc/liveness buffers across compiles; deps: Speed up linear scan allocator; verification: allocation churn drops in sample output and throughput increases.
