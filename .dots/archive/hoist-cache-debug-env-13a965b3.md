---
title: Cache debug env probe
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:59:44.796175+01:00\""
closed-at: "2026-02-17T16:01:41.625697+01:00"
close-reason: "discarded: no >=5% positive gain; perf gate failed on large(100) +9.57%; reverted"
---

src/codegen/context.zig DebugOptions.loadFromEnv repeatedly probes HOIST_DUMP_IR when unset, adding overhead to every compile. Add one-time env probe flag and skip repeated lookups. Validate with bench-gate A/B and tests; keep only if >=5% gains.
