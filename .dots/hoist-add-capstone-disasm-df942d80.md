---
title: Add Capstone disasm wrapper
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:04.194987+02:00"
---

Create src/tools/disasm.zig that wraps system Capstone library via @cImport. Expose disassemble(bytes) -> []Instruction. Use for test verification. Deps: none. Verify: zig build test
