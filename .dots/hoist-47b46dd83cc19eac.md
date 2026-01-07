---
title: Implement classifyArgs function
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:02:02.837195+02:00"
closed-at: "2026-01-06T22:43:07.453876+02:00"
---

File: src/backends/aarch64/abi.zig - Implement classifyArgs(sig: Signature) -> []ArgLocation. Iterate parameters, track gpr_idx=0, fpr_idx=0, stack_offset=0. Call classifyIntArg for int types (TODO: add classifyFloatArg later). Allocate result array. Dependencies: hoist-47b46d630fb52389.
