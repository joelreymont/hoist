---
title: Add integer argument passing e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:33:35.238040+02:00"
closed-at: "2026-01-07T08:13:23.095822+02:00"
---

File: src/backends/aarch64/e2e_int_args_test.zig (new). Test: build IR function with 10 int args, compile, execute via JIT, verify args passed correctly. Verify: X0-X7 for first 8, stack for remaining. Test edge cases: 0 args, max register args, >8 args. ~80 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
