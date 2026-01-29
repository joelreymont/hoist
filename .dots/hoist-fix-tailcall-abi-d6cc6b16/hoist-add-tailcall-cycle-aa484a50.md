---
title: Add Tailcall Cycle Breaking
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.392761+01:00"
---

Context: src/machinst/tailcall.zig:209; cause: cycles clobber regs; fix: temp regs/stack slots for cycles; deps: hoist-fix-tailcall-arg-b46707e6; verification: unit test with cycle
