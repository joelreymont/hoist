---
title: Add parallel module compile API
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.924625+01:00"
---

Context: src/context.zig and module entrypoints; cause: no public API to compile function batches in parallel; fix: add compileFunctionsParallel API with deterministic result mapping by function index; deps: Implement real worker compile path; verification: API tests pass on mixed success/failure cases.
