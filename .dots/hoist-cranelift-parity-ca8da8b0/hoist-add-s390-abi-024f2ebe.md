---
title: Add s390 abi
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.495094+02:00\""
closed-at: "2026-01-23T14:16:17.336422+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/abi.zig:111-187
Root cause: s390x ABI not implemented.
Fix: add src/backends/s390x/abi.zig implementing SysV s390x ABI.
Why: correct calling convention.
Deps: Add s390 regs.
Verify: ABI tests.
