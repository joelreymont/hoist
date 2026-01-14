---
title: Fix SIMD three-same enc
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"\\\\\\\"\\\\\\\\\\\\\\\"2026-01-14T14:14:35.854767+02:00\\\\\\\\\\\\\\\"\\\\\\\"\\\"\""
closed-at: "2026-01-14T14:26:04.451414+02:00"
close-reason: fix vec_sub U bit
---

Files: src/backends/aarch64/emit.zig:11671-11887. Root cause: SIMD three-same encodings use 0b01110<<23 and size<<21, off by one bit. Fix: move base field to bits 28-24, size to 23-22, fixed bit to 21 across vec_add/sub/addp/mul/sdot/udot/cmeq/cmgt/cmge. Why: match assembler encodings (e.g., add v0.4s -> 0x4EA28420).
