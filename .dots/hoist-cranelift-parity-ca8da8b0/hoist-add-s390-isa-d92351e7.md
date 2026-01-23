---
title: Add s390 isa
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.501128+02:00\""
closed-at: "2026-01-23T14:17:33.431916+02:00"
---

Files: src/backends/x64/isa.zig:1-60, src/context.zig:61-88
Root cause: s390x ISA not wired into compile pipeline.
Fix: add src/backends/s390x/isa.zig and integrate compileFunction.
Why: enable s390x compilation.
Deps: Add s390 insts, Add s390 abi, Wire s390 lower.
Verify: compile smoke tests.
