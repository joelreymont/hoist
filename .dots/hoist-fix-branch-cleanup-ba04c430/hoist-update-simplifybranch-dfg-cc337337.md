---
title: Update SimplifyBranch DFG Removal
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.411785+01:00\\\"\""
closed-at: "2026-01-29T10:30:00.685767+01:00"
close-reason: done
---

Context: src/codegen/opts/simplifybranch.zig:75; cause: removes only layout; fix: call new DFG delete and update block terminator; deps: hoist-add-dfg-instruction-935ff589; verification: simplifybranch tests
