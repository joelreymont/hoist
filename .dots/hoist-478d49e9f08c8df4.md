---
title: Add multi_lane usage patterns
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T12:20:16.293015+02:00"
closed-at: "2026-01-04T12:36:52.191584+02:00"
---

After implementing multi_lane extractor, add common usage patterns: (A) Exact match for instruction selection: (vecop_int_cmpeq (multi_lane 8 16)) -> CmpEq8x16; (B) Wildcard for generic ops: (sse_and (multi_lane _ _) x y) -> x64_pand; (C) Lane-specific with wildcard count: (lane_size (multi_lane 32 _)) -> Size32; (D) Extract size for emission: (multi_lane size _) then use size in MInst. Total ~33 rules needed across vector ops. Files: src/isle/lowering.isle, instruction selection rules.
