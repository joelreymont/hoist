---
title: Fix test compilation errors in stub code
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T12:58:14.446238+02:00"
closed-at: "2026-01-05T13:03:15.002137+02:00"
---

File: src/codegen/compile.zig:394,428,494. Errors in legalize() lower() allocateRegisters() stubs. These are unexecuted code paths. Options: (1) stub out the functions, (2) implement VCodeBuilder, (3) guard with comptime flags. Blocks: test suite compilation.
