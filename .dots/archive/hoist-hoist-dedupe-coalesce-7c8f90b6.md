---
title: Hoist dedupe coalesce mates
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:01:36.422136+01:00\\\"\""
closed-at: "2026-02-17T17:04:56.446537+01:00"
close-reason: discarded (same-tree rerun showed no >=5% stable gains)
---

Full context: src/regalloc/linear_scan.zig addCoalescePair appends mate indices without duplicate checks; repeated mov_rr edges can grow mate lists and slow getCoalesceHint scans. Cause: unbounded duplicate coalesce edges. Fix: append coalesce mates uniquely (and ignore self-pairs) to keep hint lists tight. Proof: zig build test + same-tree A/B via bench-log + bench-compare; keep only if >=5% positive gains.
