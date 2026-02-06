---
title: Add try_call CFG edge test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T10:16:59.484176+01:00\""
closed-at: "2026-02-06T10:19:14.368563+01:00"
close-reason: added CFG try_call exception successor test
---

src/ir/cfg.zig:474 add regression test that try_call records normal and exception successors in CFG; verifies exceptionSuccIter includes landing block. Depends on hoist-exceptions-runtime-d1afab88.
