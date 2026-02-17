---
title: Persist regalloc state
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:42:02.627626+01:00\\\"\""
closed-at: "2026-02-17T17:52:09.989557+01:00"
close-reason: completed
blocks:
  - hoist-dense-liveness-map-ed60eafe
---

Full context: src/codegen/compile.zig:6542-6561 rebuilds pools/linear-scan each compile. Cause: repeated allocator/setup overhead in hot loop. Fix: persist allocatable pools + linear-scan working storage in codegen context and reset for reuse each compile; verify no-regression + >=5% retained uplift.
