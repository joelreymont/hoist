---
title: ABI tailcalls
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-02T23:57:18.057731+01:00\""
closed-at: "2026-02-05T22:35:36.330133+01:00"
close-reason: Tailcall ABI/HFA stack args implemented and tested
blocks:
  - hoist-mach-o-writer-00aa8ebe
---

File: src/backends/aarch64/abi.zig:1510; cause: aggregate ABI and tailcall details incomplete; fix: implement HFA/HVA, tailcall ABI, stack args; why: correct calls/returns.
