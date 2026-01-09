---
title: Lower HFA return values
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:19:22.654907+02:00\""
closed-at: "2026-01-09T12:38:27.671908+02:00"
---

Detect HFA return in isle_helpers.zig:aarch64_call result handling. Assemble 2-4 FP values from V0-V3 into struct. Use struct construction IR or memory copy. ~90 min.
