---
title: Create DomTree type
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:20:19.090319+02:00"
---

File: src/ir/domtree.zig (new). Define DomTree struct with dom_parent: HashMap(Block, Block), cfg: *CFG. Add init/deinit. Add idom(block) method to query immediate dominator. ~10 min.
