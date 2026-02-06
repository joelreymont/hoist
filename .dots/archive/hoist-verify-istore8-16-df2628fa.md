---
title: Verify istore8/16/32 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T11:05:01.152448+01:00\""
closed-at: "2026-02-06T11:10:03.131957+01:00"
close-reason: Verified existing coverage in src/backends/aarch64/lower_test.zig and tests/isle_memory.zig; full zig build test passes.
---

src/codegen/compile.zig:4786,4795,4804 verify istore8/16/32 lower to STRB/STRH/STR W-reg on AArch64; add targeted tests in tests/e2e_jit.zig or backend tests; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
