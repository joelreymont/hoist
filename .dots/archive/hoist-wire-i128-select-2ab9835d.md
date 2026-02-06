---
title: Wire i128 select condition lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:56:12.134838+01:00\""
closed-at: "2026-02-07T01:06:15.957959+01:00"
close-reason: Completed
---

src/backends/aarch64/lower.isle:1806-1841 has select/select_spectre_guard with i128 condition as aarch64_unimplemented. Add helper in src/backends/aarch64/isle_helpers.zig to compare merged i128 lanes against zero and drive existing csel path; wire both rules; add lower_test regression proving no unimplemented for i128 condition select; run zig build test -j1 --global-cache-dir .zig-global-cache.
