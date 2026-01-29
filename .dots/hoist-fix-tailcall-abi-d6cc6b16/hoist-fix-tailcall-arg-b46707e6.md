---
title: Fix Tailcall Arg Move Ordering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.387814+01:00\""
closed-at: "2026-01-29T15:20:10.606136+01:00"
---

Context: src/machinst/tailcall.zig:178; cause: naive move list; fix: dependency graph + topo order for reg->reg moves; deps: hoist-fix-tailcall-abi-d6cc6b16; verification: unit test for move order
