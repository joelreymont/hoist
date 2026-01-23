---
title: Fix adr/adrp enc
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"\\\\\\\"2026-01-14T14:14:31.035699+02:00\\\\\\\"\\\"\""
closed-at: "2026-01-23T08:43:11.451940+02:00"
close-reason: adrp encodes page offset, tests sign-extend
---

Files: src/backends/aarch64/emit.zig:4891,4918 and tests at 9860-10040. Root cause: ADRP encodes byte offset without page shift; ADR/ADRP tests decode imm without sign extension. Fix: enforce 4KB alignment, encode page offset (offset>>12), sign-extend 21-bit imm in tests and for ADRP compare (imm<<12). Why: correct PC-relative address formation per ARM ARM.
