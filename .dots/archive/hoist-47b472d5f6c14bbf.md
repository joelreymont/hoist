---
title: Add vector SUB lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:03:26.574283+02:00"
closed-at: "2026-01-06T20:45:29.445013+02:00"
---

File: src/codegen/compile.zig - Lower isub with vector type to vec_sub. Same lane size detection as ADD. Emit vec_sub instruction. Dependencies: hoist-47b472751cb83d73.
