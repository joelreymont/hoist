---
title: Implement reverse postorder traversal
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:25:27.860213+02:00\""
closed-at: "2026-01-08T21:28:41.825278+02:00"
---

File: src/ir/domtree.zig. Add reversePostorder(cfg, allocator) -> []Block. DFS from entry, push to stack on finish. Reverse stack to get RPO. Needed for dominator algorithm. ~10 min.
