---
title: Merge results deterministically
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.930685+01:00"
---

Context: src/codegen/parallel.zig result collector; cause: worker completion order is nondeterministic; fix: sort/assemble outputs by function index before returning; deps: Add parallel module compile API; verification: repeated runs produce byte-identical ordering.
