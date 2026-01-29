---
title: Handle Tailcall Stack Args AArch64
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.397534+01:00\""
closed-at: "2026-01-29T15:19:07.943460+01:00"
---

Context: src/backends/aarch64/isle_helpers.zig:3519; cause: tailcall rejects stack args; fix: spill stack args with alignment and frame adjust; deps: hoist-add-tailcall-cycle-aa484a50; verification: tests/aarch64_stack_args.zig + tests/e2e_tail_calls.zig
