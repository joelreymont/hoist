---
title: "ISLE coverage: Add coverage tracking structure"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T19:11:34.898288+02:00\""
closed-at: "2026-01-08T19:16:01.984598+02:00"
---

File: Create src/backends/aarch64/isle_coverage.zig. HashMap<String, u32> for rule_name → invocation_count. Basic init/deinit/record/report functions. Depends on hoist-47cc3acf72e365f0. Completable in 20-30min.
