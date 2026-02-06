---
title: Fix AArch64 pinned reg parity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T10:14:52.893863+01:00\""
closed-at: "2026-02-06T10:14:58.015963+01:00"
close-reason: platform pinned reg parity fixed in ISLE helpers
---

src/backends/aarch64/isle_helpers.zig:2676 and :2683 now select pinned reg by platform (x18 Darwin, x28 others) to match ABI/isle_impl; add pinnedRegNum test. Depends on hoist-exceptions-runtime-d1afab88.
