---
title: Wire function inliner
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:07.185206+02:00"
---

In src/codegen/optimize.zig, add inlining pass to pipeline. Clone and remap IR. Deps: Add function inliner struct. Verify: zig build test
