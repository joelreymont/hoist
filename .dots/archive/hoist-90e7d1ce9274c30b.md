---
title: Implement live range overlap
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:20:48.787473+02:00\""
closed-at: "2026-01-08T21:27:28.084963+02:00"
---

File: src/regalloc/interference.zig. Add overlaps(lr1, lr2) function: two LiveRanges overlap if (lr1.start <= lr2.end && lr2.start <= lr1.end). Used to detect interference. ~10 min.
