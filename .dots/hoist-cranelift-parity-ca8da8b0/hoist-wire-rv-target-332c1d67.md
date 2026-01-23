---
title: Wire rv target
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.441917+02:00\""
closed-at: "2026-01-23T11:00:44.045518+02:00"
---

Files: src/context.zig:66-123, src/context.zig:161-174
Root cause: Arch enum lacks riscv64 and targetNative mapping.
Fix: add .riscv64 to Arch and target mapping/default call conv.
Why: expose riscv64 backend.
Deps: Add rv isa.
Verify: context tests in src/context.zig.
