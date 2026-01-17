---
title: Add bytes differential testing
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:54:14.666472+02:00"
---

Create tests/diff_bytes.zig. Compare emitted machine code bytes vs Cranelift. Deps: Add Capstone disasm wrapper. Verify: zig build test
