---
title: Add Platform enum for Darwin/Linux detection
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:01.457439+02:00"
closed-at: "2026-01-07T07:39:14.622354+02:00"
---

File: src/backends/aarch64/abi.zig, new Platform enum. Values: Darwin, Linux, Other. Detection: comptime builtin.os.tag == .macos or runtime. Field: platform: Platform in ABICallee. Used for X18 reservation check and red zone behavior. ~20 lines. Blocks: X18 reservation, red zone handling.
