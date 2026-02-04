---
title: A64 vector helpers
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T07:28:16.569274+01:00\\\"\""
closed-at: "2026-02-05T18:46:01.119813+01:00"
close-reason: Fix vector helpers + size mapping
---

src/backends/aarch64/isle_helpers.zig:3431,3527; cause: vector helper constructors pass VReg where Inst expects Reg; vectorSizeFromType switches on packed ir.types.Type; fix: wrap VReg->Reg via Reg.fromVReg, rewrite vectorSizeFromType using Type helpers (isVector/bits/laneBits) and update inst field names (cmp_imm/cset); proof: zig build test --global-cache-dir .zig-global-cache
