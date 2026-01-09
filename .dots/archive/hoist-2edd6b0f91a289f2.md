---
title: Implement simple copy propagation pass
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:48:06.527630+02:00\""
closed-at: "2026-01-09T07:58:50.152264+02:00"
---

Create dedicated copyprop.zig for simple copies (x = y). Currently embedded in other passes. Extract to standalone pass for clarity and Cranelift parity. Use dataflow to track copy chains. Files: src/codegen/opts/copyprop.zig (new), ~200 lines. ~60 min.
