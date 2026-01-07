---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:03.914947+02:00"
closed-at: "2026-01-01T08:53:10.936656+02:00"
close-reason: Deferred - ARM64 only initially, x64 later
---

Port x64 ABIs from cranelift/codegen/src/isa/x64/abi.rs (~800 LOC). Create src/backends/x64/abi.zig with System V AMD64 and Windows x64 calling conventions, argument passing, stack management. Depends on: x64 inst (hoist-474ded8520631fd3), ABI framework (hoist-474dec120ced1e54). Files: src/backends/x64/abi.zig, abi_test.zig. Calling conventions for x64.
