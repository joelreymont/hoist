---
title: Add range-based optimizations
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:46:07.383076+02:00"
---

Use ranges for: bounds check elimination (array[i] when i in [0, len)), overflow check removal, branch prediction hints. Integrate with SCCP. Files: src/codegen/opts/range_opts.zig (new), ~300 lines. ~150 min.
