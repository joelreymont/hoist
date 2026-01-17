---
title: Add parallel compile support
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:54:22.070991+02:00"
---

Make CompilationContext thread-safe. Add mutex around shared state. Support parallel function compilation. Deps: none. Verify: zig build test
