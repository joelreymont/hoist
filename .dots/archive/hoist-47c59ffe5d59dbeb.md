---
title: Create MockABI for testing without full pipeline
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:58.640744+02:00"
closed-at: "2026-01-07T07:49:30.085349+02:00"
---

File: src/backends/aarch64/mock_abi.zig (new). Minimal ABICallee/ABICaller mocks for unit testing ABI logic. Methods: setNumArgs, setNumRets, setLocalsSize, computeFrame. Track: frame_size, stack_args, register_args, callee_saves. No instruction emission, return fake offsets. Used by: frame layout tests, arg classification tests. ~200 lines. Unblocks: all ABI unit tests.
