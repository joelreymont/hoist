---
title: Fix isb enc
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T14:45:44.211249+02:00\""
closed-at: "2026-01-14T14:49:33.992067+02:00"
close-reason: encode 0xD5033FDF
---

File: src/backends/aarch64/emit.zig:3278. Root cause: ISB uses low bits 0xFF, should be 0xDF (bit5 cleared). Fix: encode trailing bits as 0b11011111 so ISB matches ARM ARM. Verify: zig build test --cache-dir /tmp/hoist-zig-cache --global-cache-dir /tmp/hoist-zig-global.
