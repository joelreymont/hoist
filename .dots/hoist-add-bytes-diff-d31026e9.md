---
title: Add bytes diff testing
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:06:33.875441+02:00"
---

Files: tests/diff_cranelift.zig
What: Compare emitted machine code bytes against Cranelift
Method: Compile same IR, disassemble both, compare
Deps: hoist-add-capstone-disasm-df942d80
Verification: Byte-identical output (or documented differences)
