---
title: Add ty_vec128 usage patterns
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T12:20:22.967818+02:00"
closed-at: "2026-01-04T12:36:52.196514+02:00"
---

After implementing ty_vec128 extractor, add size-based patterns: (1) Generic vector ops on any 128-bit vector: (has_type (ty_vec128 ty) (bnot x)) -> (not x (vector_size ty)); (2) Narrowing ops: (has_type (ty_vec128_int ty) (snarrow x y)) -> specialized instruction; (3) Bitwise ops: (has_type (ty_vec128 ty) (band x (bnot y))) -> bic_vec. Total ~7 rules. Used when lane structure doesn't matter, only total vector size. Files: src/isle/lowering.isle
