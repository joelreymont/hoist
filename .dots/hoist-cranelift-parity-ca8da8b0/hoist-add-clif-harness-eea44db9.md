---
title: Add clif harness
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.811129+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/docs/testing.md:17-75
Root cause: no filetest harness or clif parsing.
Fix: add test runner for .clif files and filecheck-like matching.
Why: parity with Cranelift filetests.
Deps: Add ir parser, Add clif tool.
Verify: clif harness tests.
