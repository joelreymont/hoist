---
title: Complete ISLE constructor codegen
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:05:21.649710+02:00"
---

Files: src/dsl/isle/codegen/constructors.zig:107-118
What: Finish constructor code generation
Currently: Basic constructors work, complex ones incomplete
Fix: Handle multi-result constructors, fallible constructors
Verification: All aarch64_lower.isle constructors compile
