---
title: Optimizer/legalization
status: active
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.883460+01:00\""
blocks:
  - hoist-finish-mach-o-42e5a740
---

Context: src/codegen/{peephole,optimize,opts,compile}.zig; cause: multiple TODO optimizations and legalization stubs; fix: implement missing passes; deps: none; verification: zig build test + perf benches
