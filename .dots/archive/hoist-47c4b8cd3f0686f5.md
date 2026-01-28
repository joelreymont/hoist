---
title: Enforce frame pointer for large/dynamic frames
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:28:19.884819+02:00"
closed-at: "2026-01-07T06:45:49.725229+02:00"
---

File: src/backends/aarch64/abi.zig - Add logic to require frame pointer (X29/FP) for functions with large frames or dynamic allocations. Condition: frame_size > threshold OR has_dynamic_alloc. Rationale: Stack unwinding, debugging require stable frame reference. Implementation: Set uses_frame_pointer flag in frame layout, emit FP setup/teardown in prologue/epilogue. ABI correctness requirement.
