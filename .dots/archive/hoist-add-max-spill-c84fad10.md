---
title: Add max spill offset boundary test
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:50:56.901125+01:00\\\"\""
closed-at: "2026-02-06T21:53:10.680298+01:00"
close-reason: Added regalloc bridge test for max in-range spill slot offset
---

src/backends/aarch64/regalloc_bridge.zig: add regression test that SpillSlot.new(32767) is accepted and emitted as exact offset in reload/store sequence. Complements oversized spill-slot rejection test.
