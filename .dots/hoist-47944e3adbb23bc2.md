---
title: Implement regalloc2 algorithm integration
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T20:42:33.476029+02:00"
closed-at: "2026-01-05T11:22:46.545464+02:00"
---

File: src/backends/aarch64/isa.zig:228 - Comment 'TODO: Actually run regalloc2 algorithm here'. Currently stubs allocation with identity mapping (vreg i -> preg i). Need to call regalloc2 API from src/machinst/regalloc2/{api,liveness,moves}.zig to perform real register allocation.
