---
title: Wire linear scan to compile pipeline
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:00:34.326777+02:00"
closed-at: "2026-01-06T22:43:07.483075+02:00"
---

File: src/codegen/compile.zig - Add option to use LinearScanAllocator instead of TrivialAllocator. Controlled by compile flag or opt level. Call liveness analysis, then linear scan, then register rewriting. Dependencies: hoist-47b468366477f7e4.
