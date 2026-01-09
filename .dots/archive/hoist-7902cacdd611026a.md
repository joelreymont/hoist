---
title: Add strength reduction for division
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:19:50.327476+02:00\""
closed-at: "2026-01-09T08:23:02.771477+02:00"
---

Add x/2^n → x>>n pattern to instcombine.zig. Check if divisor is power of 2, replace sdiv/udiv with ashr/lshr. Common pattern, ~5-10% speedup. ~30 min.
