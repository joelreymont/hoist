---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T09:23:59.380231+02:00"
closed-at: "2026-01-01T10:25:25.221626+02:00"
close-reason: "Completed foundation layer: entity, bforest. Ready for IR layer."
---

src/foundation/entity.zig keeps getting truncated to 3 lines. Full implementation: EntityRef pattern, PrimaryMap (std.ArrayList wrapper), SecondaryMap (std.ArrayList wrapper), EntitySet (std.bit_set.DynamicBitSet wrapper). Need ~330 LOC with tests. See ../wasmtime/cranelift/entity/src/ for reference.
