---
title: Fix tailcall structs
status: open
priority: 1
issue-type: task
created-at: "2026-01-30T18:13:06.076677+01:00"
---

Context: src/backends/aarch64/isle_helpers.zig:3191,3618; cause: tail call path skips struct stack args and indirect tail call uses simplified ABI; fix: use CallLayout for tail call register + stack args incl struct/HFA/HVA; deps: hoist-add-call-layout-1873bf08; verification: add tailcall ABI unit test + zig build test
