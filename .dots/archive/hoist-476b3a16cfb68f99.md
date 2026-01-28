---
title: "Fix encodeLogicalImmediate repeating pattern detection in src/backends/aarch64/encoding.zig:157 - fails for 0x00FF00FF00FF00FF (should detect 16-bit repeat) and 0xAAAAAAAAAAAAAAAA (should detect 2-bit repeat), element_size loop not finding correct repeating size"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-02T19:42:01.910213+02:00"
closed-at: "2026-01-02T19:45:03.202492+02:00"
close-reason: completed - commit 9c8402f, all encoding tests pass
---
