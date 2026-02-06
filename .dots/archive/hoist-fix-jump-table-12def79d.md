---
title: Fix jump-table offset base
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:11:16.395960+01:00\""
closed-at: "2026-02-06T23:13:23.186891+01:00"
close-reason: Compute all jump-table entries relative to table base
---

Context: /Users/joel/Work/hoist/src/machinst/buffer.zig:586; cause: emitJumpTables computes per-entry relative offset from current entry location, but jt_sequence adds table_base, so offsets must be table-base-relative; fix: compute all entries as target-table_base and add regression test with multiple entries; deps: hoist-validate-jump-table-1e73b8b5; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
