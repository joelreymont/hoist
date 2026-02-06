---
title: Test i128 spectre-select lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:19:53.390977+01:00\""
closed-at: "2026-02-06T21:21:03.212802+01:00"
close-reason: Cover i128 cond merge path for spectre-guard select.
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:3559 now handles .select_spectre_guard with i128 cond path but lacks regression coverage; cause: behavior can regress silently; fix: add compile-level test in /Users/joel/Work/hoist/tests/aarch64_ccmp.zig asserting ORR+CMP64+CSEL shape; deps: hoist-fix-i128-select-47dbc271; verification: zig build test -j1 --global-cache-dir .zig-global-cache
