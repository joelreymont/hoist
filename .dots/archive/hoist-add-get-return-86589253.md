---
title: Add get_return_address op
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:33.886957+02:00\""
closed-at: "2026-01-24T00:08:26.315940+02:00"
---

Files: src/backends/aarch64/isle_impl.zig, src/ir/opcodes.zig
What: Implement get_return_address intrinsic
AArch64: Load from [X29+8] for frame pointer mode, or X30 if available
Use: Stack unwinding, debugging
Verification: Test returns correct address in call chain
