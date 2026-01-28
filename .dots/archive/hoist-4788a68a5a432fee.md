---
title: "Dot 1.4: Implement call opcode"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T06:48:15.473230+02:00"
closed-at: "2026-01-04T07:01:19.122138+02:00"
---

Files: lower.isle:1830 (3 rules), isle_helpers.zig:1780. Rules: handle func_ref_data near/far/tail-eligible. Helper: aarch64_call - emit BL with relocation, handle ABI arg marshaling. Test: direct call with args. 45min
