---
title: ABI tailcalls
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:57:18.057731+01:00"
blocks:
  - hoist-mach-o-writer-00aa8ebe
---

File: src/backends/aarch64/abi.zig:1510; cause: aggregate ABI and tailcall details incomplete; fix: implement HFA/HVA, tailcall ABI, stack args; why: correct calls/returns.
