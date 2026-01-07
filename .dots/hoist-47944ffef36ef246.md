---
title: Implement bounds checking with traps
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T20:43:03.104375+02:00"
closed-at: "2026-01-05T11:23:40.371559+02:00"
---

File: src/backends/aarch64/isle_helpers.zig:61 - TODO 'Implement full bounds checking with traps'. Currently heap_addr validation is stubbed. Need to emit conditional trap instructions for out-of-bounds memory access following WebAssembly semantics.
