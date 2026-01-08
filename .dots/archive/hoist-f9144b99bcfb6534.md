---
title: Add dominates query method
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:20:31.232144+02:00\""
closed-at: "2026-01-08T21:28:41.835163+02:00"
---

File: src/ir/domtree.zig. Add dominates(a, b) method: walk from b up dom_parent chain, return true if reach a. Used for reload hoisting and optimizations. ~10 min.
