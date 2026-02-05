---
title: Reject stack alloc in regalloc bridge
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T00:17:47.524020+01:00\""
closed-at: "2026-02-06T00:19:39.886882+01:00"
close-reason: Made stack allocations fail explicitly in bridge
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:1126; cause: stack allocations from regalloc2 surface as generic VRegNotAllocated, hiding spill-path gaps; fix: return explicit StackAllocationUnsupported and add regression test; deps: hoist-stage-regalloc-parity-83427050; verification: zig build test -j1 --global-cache-dir .zig-global-cache
