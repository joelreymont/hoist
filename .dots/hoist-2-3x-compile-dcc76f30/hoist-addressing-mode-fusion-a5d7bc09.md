---
title: Addressing mode fusion
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:42:08.536334+01:00"
---

Fuse more addressing/load-store forms to reduce instruction selection work and emit passes. files: src/backends/aarch64/isle_helpers.zig, src/backends/aarch64/inst.zig. Cause: extra canonicalization and post-lowering fixups. Fix: emit final forms earlier in ISLE lowering. Why: less rewrite/emit overhead.
