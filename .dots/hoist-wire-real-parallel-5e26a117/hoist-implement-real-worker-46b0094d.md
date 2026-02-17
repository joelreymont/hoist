---
title: Implement real worker compile path
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.918701+01:00"
---

Context: src/codegen/parallel.zig:275-283; cause: compileFunction returns placeholder empty code; fix: invoke real codegen pipeline per worker with isolated contexts; deps: Wire real parallel compile; verification: worker outputs valid compiled artifacts and error propagation works.
