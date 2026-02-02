---
title: Implement partial loop unroll
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.918944+01:00"
blocks:
  - hoist-legalize-vector-types-030df554
---

Context: src/codegen/opts/loop_unroll.zig:200; cause: partial unroll TODO; fix: implement bounded unroll factor with cleanup loop; deps: loop analysis; verification: add loop_unroll tests + zig build test
