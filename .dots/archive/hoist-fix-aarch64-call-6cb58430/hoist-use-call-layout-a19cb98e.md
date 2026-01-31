---
title: Use call layout
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-30T18:12:38.393037+01:00\\\"\""
closed-at: "2026-01-31T09:19:41.616318+01:00"
close-reason: completed
---

Context: src/backends/aarch64/isle_helpers.zig:3930,4445,4835; cause: duplicate arg marshalling and inconsistent stack offsets; fix: drive call/call_indirect/try_call with CallLayout locs; deps: hoist-add-call-layout-1873bf08; verification: zig build test + new abi layout tests
