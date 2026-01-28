---
title: "P1.1: Add instruction encoding unit tests"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:10:39.853559+02:00"
closed-at: "2026-01-05T21:08:01.850548+02:00"
---

File: tests/aarch64_encoding.zig (new) - Test MOVZ w0, #42 = 0x52800540, MOV w0, w1 = 0x2A0103E0, ADD, MUL, RET. Verify each encoding against ARM reference manual. Cross-check with llvm-mc or online assembler.
