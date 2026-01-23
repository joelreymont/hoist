---
title: Add execution diff testing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:06:34.691060+02:00\""
closed-at: "2026-01-26T09:49:33.310764+01:00"
---

Files: tests/diff_cranelift.zig
What: Run JIT-compiled code from both compilers, compare results
Method: Generate random inputs, execute both versions, compare
Deps: hoist-add-ir-diff-testing (previous)
Verification: Identical execution results
