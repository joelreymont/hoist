---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:18.923768+02:00"
closed-at: "2026-01-01T09:05:26.851797+02:00"
close-reason: Replaced with correctly titled task
---

Port ABI framework from cranelift/codegen/src/machinst/abi.rs (~1200 LOC). Create src/machinst/abi.zig with ABIMachineSpec interface, calling conventions, stack management, prologue/epilogue generation. Depends on: VCode (hoist-474deb7f9da39c2f), MachInst (hoist-474deb32162db016). Files: src/machinst/abi.zig. Abstract ABI interface for backends.
