---
title: Zcheck property errors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T17:13:04.514017+01:00\""
closed-at: "2026-02-01T17:13:27.962061+01:00"
close-reason: completed
---

src/backends/aarch64/zcheck_properties.zig:51+ cause: property tests mask allocator/emit errors with catch return false; fix: add shared zcheck_fallible helper and convert properties to !void with try; why: no error masking.
