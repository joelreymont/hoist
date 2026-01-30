---
title: Backend parity
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:09:43.053725+01:00"
---

Context: src/codegen/compile.zig:4976-4990; cause: non-AArch64 lowering paths are TODO; fix: complete x64/riscv64/s390x lowering pipeline; deps: none; verification: zig build test (backend-specific)
