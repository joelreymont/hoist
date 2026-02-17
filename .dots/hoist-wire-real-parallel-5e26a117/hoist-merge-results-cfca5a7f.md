---
title: Merge results deterministically
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.930685+01:00\""
closed-at: "2026-02-17T13:46:02.039998+01:00"
close-reason: implemented deterministic result assembly in src/codegen/parallel.zig via ResultCollector.takeSorted and ParallelCompiler.takeResultsSorted (sorted by func_idx), used by Context.compileFunctionsParallel and validated by sorted-result tests
---

Context: src/codegen/parallel.zig result collector; cause: worker completion order is nondeterministic; fix: sort/assemble outputs by function index before returning; deps: Add parallel module compile API; verification: repeated runs produce byte-identical ordering.
