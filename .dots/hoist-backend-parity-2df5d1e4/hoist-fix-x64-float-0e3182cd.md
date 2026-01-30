---
title: Fix x64 float return
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:09:47.569033+01:00\\\"\""
closed-at: "2026-01-30T11:28:23.301194+01:00"
close-reason: completed
---

Context: src/generated/x64_lower_generated.zig:136-158; cause: return lowering rejects float types; fix: move float return to XMM0 and emit ret; deps: none; verification: zig build test
