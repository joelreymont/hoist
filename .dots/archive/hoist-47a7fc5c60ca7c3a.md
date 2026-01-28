---
title: "P4: Add debug tools and clean up"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:11:19.286995+02:00"
closed-at: "2026-01-05T21:00:53.773108+02:00"
---

Files: src/codegen/vcode.zig (add print method), tests/e2e_jit.zig (add disassemble helper with objdump). Guard debug prints with compile-time flag. Success: clear debug output available, no spam in normal runs.
