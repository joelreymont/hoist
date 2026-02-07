---
title: Add differential JIT/interpreter fuzzing
status: open
priority: 2
issue-type: task
created-at: "2026-02-07T01:09:47.145824+01:00"
---

fuzz/fuzz_compile.zig:1-260 currently only compiles random IR and never compares semantics. Implement differential mode that runs interpreter and JIT on same generated function/inputs, compares result values, and prints reproducible mismatch seeds/IR. Wire into zig build fuzz path. Depends on existing fuzz infra. Verify with zig build test and zig build fuzz.
