---
title: Hoist single-probe noteRangeUse
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:05:54.124331+01:00\\\"\""
closed-at: "2026-02-17T17:08:31.998451+01:00"
close-reason: "discarded (same-tree A/B fail: large100 +12.03%, large5000 +7.31%)"
---

Full context: src/regalloc/liveness.zig noteRangeUse does map.get followed by map.put on first-seen vregs, causing two hash probes on hot path. Cause: split lookup/insert pattern in liveness range construction. Fix: switch to getOrPut single-probe insertion and in-place update for existing entries. Proof: zig build test + same-tree A/B via bench-log + bench-compare; keep only if >=5% positive gains.
