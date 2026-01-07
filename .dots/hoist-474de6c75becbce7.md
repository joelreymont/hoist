---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:42:50.142709+02:00"
closed-at: "2026-01-01T09:05:17.917114+02:00"
close-reason: Replaced with correctly titled task
---

Port cranelift-bforest (~3,554 LOC). Create src/foundation/bforest.zig with BTreeMap, BTreeSet, specialized for compiler use. Depends on: entity (hoist-474de68d56804654). Files: src/foundation/bforest.zig, bforest_test.zig. Used for ordered maps/sets in compiler.
