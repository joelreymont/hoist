---
title: Wire Prologue/Epilogue
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.436360+01:00\""
closed-at: "2026-01-29T16:19:08.265709+01:00"
close-reason: completed
---

Context: src/codegen/compile.zig:5024; cause: missing frame setup/teardown; fix: insert prologue/epilogue based on ABI; deps: hoist-wire-regalloc-and-b0b3a9b4; verification: aarch64_stack_args tests
