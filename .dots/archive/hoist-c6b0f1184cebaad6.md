---
title: Create peephole optimization pass infrastructure
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T15:16:31.163331+02:00\""
closed-at: "2026-01-08T15:58:48.087923+02:00"
---

File: Create src/codegen/peephole.zig. Build framework for post-regalloc instruction pattern matching and rewriting. Needs: instruction iterator, pattern matcher, safe rewrite mechanism. Required before load/store combining.
