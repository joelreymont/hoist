---
title: Wire regalloc2 to pipeline
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:49.970134+02:00"
---

In src/backends/aarch64/isa.zig:280, replace TODO stub with actual regalloc2 call. Deps: Port regalloc2 coloring. Verify: zig build test
