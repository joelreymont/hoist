---
title: Wire real parallel compile
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.599602+01:00\""
closed-at: "2026-02-17T13:54:29.937713+01:00"
close-reason: "completed parallel compile epic: real worker codegen path, public parallel batch API, deterministic result ordering, serial-vs-parallel throughput benchmark, and correctness tests (including serial/parallel byte equivalence); full test suite and bench-gate pass"
---

Context: src/codegen/parallel.zig:1-280; cause: parallel compiler path is placeholder and not wired to real compilation; fix: implement real worker compilation and integrate module-level parallel entrypoint; deps: Reuse codegen allocations; verification: multi-function compile benchmark shows scalable wall-clock speedup.
