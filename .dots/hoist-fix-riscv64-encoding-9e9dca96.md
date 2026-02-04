---
title: Fix riscv64 encoding tests
status: active
priority: 2
issue-type: task
created-at: "\"2026-02-04T16:39:07.714226+01:00\""
---

tests/riscv64_encoding.zig: failing iadd/isub/band; src/backends/riscv64/isa.zig + lower pipeline: add lowering/encoding for missing ops so lowerFunction doesn't return UnhandledInstruction. No deps. Est: 2h
