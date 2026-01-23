---
title: Complete ISLE nested patterns
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:20.219221+02:00\""
closed-at: "2026-01-26T10:09:34.359422+01:00"
---

Files: src/dsl/isle/codegen/extractors.zig:173
What: Handle nested pattern bindings in extractors
Currently: Flat patterns only, nested returns error
Fix: Recursively process sub-patterns, generate nested match code
Verification: Parse and compile nested extractor patterns
