---
title: Optimizer/legalization
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.883460+01:00\\\"\""
closed-at: "2026-02-06T10:00:09.707152+01:00"
close-reason: Implemented remaining optimizer/legalization pass gaps (loop unroll peeling + const shift/bitop immediate lowering). Backend target stubs remain tracked under backend parity dots.
blocks:
  - hoist-finish-mach-o-42e5a740
---

Context: src/codegen/{peephole,optimize,opts,compile}.zig; cause: multiple TODO optimizations and legalization stubs; fix: implement missing passes; deps: none; verification: zig build test + perf benches
