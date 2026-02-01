---
title: Coalescer OOM propagate
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:22:22.624971+01:00\""
closed-at: "2026-02-01T14:23:23.698472+01:00"
close-reason: completed
---

src/regalloc/coalesce.zig:219 cause: unite OOM masked as .pressure; fix: make tryCoalesce fallible and propagate error, add failing allocator test; why: avoid masking allocator failures.
