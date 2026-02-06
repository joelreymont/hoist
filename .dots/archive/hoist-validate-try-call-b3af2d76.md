---
title: Validate try_call e2e compile path
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:41:38.468943+01:00\\\"\""
closed-at: "2026-02-06T21:42:50.759040+01:00"
close-reason: Added AArch64 compile checks and fixed iadd_imm result types
---

tests/e2e_jit.zig:635,772,905 currently leave try_call tests mostly IR-only and exception_propagation uses iadd_imm results typed I64 under I32 signature. Fix result types to I32, remove stale skeleton comments, and add AArch64-gated compile checks (code+eh_frame/relocs) for try_call tests. Depends on hoist-harden-try-call-6b437377. Verify with zig build test -j1 --global-cache-dir .zig-global-cache.
