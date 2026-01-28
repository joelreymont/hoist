---
title: Implement move coalescing optimization
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:40.293256+02:00"
closed-at: "2026-01-06T11:07:03.989669+02:00"
---

File: src/regalloc/coalescing.zig. Eliminate redundant moves: if MOV dst, src and dst/src lifetimes don't interfere, assign same register. Recent commits show mov_rr elimination when src==dst; extend to general case. Reduces register pressure and code size. Dependencies: interference graph. Effort: 2-3 days.
