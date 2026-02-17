---
title: Addressing mode fusion
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T11:42:08.536334+01:00\\\"\""
closed-at: "2026-02-17T12:06:33.268774+01:00"
close-reason: added address-folding for iadd/isub+iconst into load/store immediate offsets across scalar/vector constructors; added regression test; validated with test+bench
---

Fuse more addressing/load-store forms to reduce instruction selection work and emit passes. files: src/backends/aarch64/isle_helpers.zig, src/backends/aarch64/inst.zig. Cause: extra canonicalization and post-lowering fixups. Fix: emit final forms earlier in ISLE lowering. Why: less rewrite/emit overhead.
