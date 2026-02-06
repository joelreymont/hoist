---
title: Add sadd_overflow_cin lowering test
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T10:26:22.858211+01:00\\\"\""
closed-at: "2026-02-06T10:29:19.850665+01:00"
close-reason: Added ADCS regression for signed carry-in overflow
---

Context: src/codegen/compile.zig:test lower uadd_overflow_cin emits ADCS; cause: signed carry-in variant needs explicit regression; fix: add shared overflow_cin ADCS helper and cover sadd_overflow_cin; deps: hoist-backend-parity-cfd28858; verification: zig build test
