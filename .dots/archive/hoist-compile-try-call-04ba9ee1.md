---
title: Compile try_call e2e path
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T22:25:12.295896+01:00\""
closed-at: "2026-02-05T22:28:23.072687+01:00"
close-reason: Compiled external try_call test and fixed exception-edge reachability in unreachable-code elimination.
---

Context: /Users/joel/Work/hoist/tests/e2e_jit.zig:986; cause: existing try_call external test only validated IR metadata and skipped codegen path; fix: compile function and assert code/eh_frame/relocs for try_call; deps: hoist-exceptions-runtime-d1afab88; verification: zig build test -j1 --global-cache-dir .zig-global-cache
