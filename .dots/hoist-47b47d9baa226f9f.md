---
title: Handle large frame immediate
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:27.302955+02:00"
closed-at: "2026-01-06T21:48:30.821982+02:00"
---

File: src/backends/aarch64/abi.zig - When frame_size >4095 (doesn't fit in ADD/SUB immediate): materialize size in temp register with MOVZ/MOVK sequence, then SUB sp, sp, Xtmp. Similarly for restore in epilogue. Dependencies: hoist-47b47c0bd288f9c1.
