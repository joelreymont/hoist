---
title: Map IP ranges to landing pads
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:20:01.486570+02:00"
---

File: src/backends/aarch64/unwind.zig. Build LSDA (Language Specific Data Area) table: map try_call instruction PC ranges to landing pad PCs. Store in FDE augmentation data. Encode as ULEB128 pairs. ~20 min.
