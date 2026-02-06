---
title: Add widen-load lowering regressions
status: open
priority: 2
issue-type: task
created-at: "2026-02-06T10:37:46.354003+01:00"
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:5255; cause: need compile-pipeline tests for uload/sload widening opcodes; fix: add AArch64 lowering tests asserting vec_ushll/vec_sshll emission for uload8x8/sload8x8/uload16x4/sload16x4/uload32x2/sload32x2; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
