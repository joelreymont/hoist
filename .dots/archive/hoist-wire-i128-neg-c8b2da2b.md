---
title: Wire i128 neg/abs lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-07T00:30:26.347195+01:00\\\"\""
closed-at: "2026-02-07T00:32:53.939351+01:00"
close-reason: i128 ineg/iabs now lower via pair helpers
---

src/backends/aarch64/lower.isle:1745-1757 has I128 ineg/iabs as aarch64_unimplemented. Add lower_ineg128/lower_iabs128 in src/backends/aarch64/isle_helpers.zig, wire ISLE decls/rules, add regression tests for emitted subs/sbcs/asr/eor sequences, run zig build test -j1 --global-cache-dir .zig-global-cache. Depends on existing i128 pair helpers.
