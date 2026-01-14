---
title: Wire s390 target
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.506863+02:00"
---

Files: src/context.zig:66-123, src/context.zig:161-174
Root cause: Arch enum lacks s390x and targetNative mapping.
Fix: add .s390x to Arch and target mapping/default call conv.
Why: expose s390x backend.
Deps: Add s390 isa.
Verify: context tests in src/context.zig.
