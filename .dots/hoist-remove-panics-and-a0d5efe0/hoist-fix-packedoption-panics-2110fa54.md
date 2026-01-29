---
title: Fix PackedOption Panics
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.548139+01:00"
---

Context: src/foundation/packed_option.zig:53; cause: unwrap/expect panics; fix: return error or optional API and update uses; deps: hoist-remove-panics-and-a0d5efe0; verification: foundation tests
