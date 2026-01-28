---
title: Implement alias query algorithm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.507175+02:00"
closed-at: "2026-01-04T04:53:46.349976+02:00"
---

File: src/codegen/opts/alias_analysis.zig - Implement alias(loc1, loc2) function: identical locations→must_alias, type-based aliasing (different types→no_alias), stack vs heap→no_alias, different stack slots→no_alias, same base+offset overlap check - Accept: Alias queries work for basic cases - Depends: 'Implement alias analysis data structures'
