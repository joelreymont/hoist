---
title: Add LSDA test for try_call
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T10:19:42.228424+01:00\""
closed-at: "2026-02-06T10:21:28.805513+01:00"
close-reason: added direct try_call LSDA scan regression test
---

src/codegen/compile.zig:6515 add regression test that collectLsdaCallSites includes direct try_call with exception successor landing pad. Depends on hoist-exceptions-runtime-d1afab88.
