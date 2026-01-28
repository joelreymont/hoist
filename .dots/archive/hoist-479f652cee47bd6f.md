---
title: Port IR pretty-printer (write.rs)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:56:23.079505+02:00"
closed-at: "2026-01-05T11:26:01.188737+02:00"
---

File: Create src/ir/writer.zig from cranelift/codegen/src/write.rs:1-120. Pretty-prints IR functions to text format for debugging. Formats instructions, blocks, values with proper indentation. Root cause: IR debugging output missing. Fix: Port display_function() and related formatters.
