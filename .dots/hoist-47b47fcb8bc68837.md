---
title: Add move coalescing candidates
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:07:03.995344+02:00"
closed-at: "2026-01-07T06:30:37.700593+02:00"
---

File: src/regalloc/coalescing.zig - Create CoalescingAnalyzer: find all mov_rr instructions. Build list of CoalesceCandidate(src_vreg, dst_vreg, inst_idx). Filter: only candidates where src and dst have same reg_class. Dependencies: none.
