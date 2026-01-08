---
title: Add dominator tree computation
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:05:25.604900+02:00"
---

File: src/ir/domtree.zig (new). Implement simple dominator tree using iterative dataflow. Store dom_parent for each block. API: computeDominators(cfg) -> DomTree. Reference Cranelift's domtree.rs. ~30 min.
