---
title: Wire real parallel compile
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.599602+01:00"
---

Context: src/codegen/parallel.zig:1-280; cause: parallel compiler path is placeholder and not wired to real compilation; fix: implement real worker compilation and integrate module-level parallel entrypoint; deps: Reuse codegen allocations; verification: multi-function compile benchmark shows scalable wall-clock speedup.
