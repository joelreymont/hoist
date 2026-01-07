---
title: "P2.5: Add missing type extractor patterns"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:31:04.164798+02:00"
closed-at: "2026-01-04T13:21:32.992995+02:00"
---

Implement ~40 rules using type extractors that Cranelift has but Hoist doesn't: multi_lane patterns (~33 rules), ty_vec128 patterns (~7 rules). These enable more pattern matching for vector ops. Est: 40-80h. File: src/backends/aarch64/lower.isle. Grep Cranelift for 'multi_lane' and 'ty_vec128'.
