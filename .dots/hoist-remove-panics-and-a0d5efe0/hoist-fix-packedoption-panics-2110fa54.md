---
title: Fix PackedOption Panics
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.548139+01:00\""
closed-at: "2026-02-01T20:41:24.828681+01:00"
close-reason: "completed: PackedOption.some/fromOptional return errors for reserved values; unwrap/expect use Error union (src/foundation/packed_option.zig:51-86), tests updated"
---

Context: src/foundation/packed_option.zig:53; cause: unwrap/expect panics; fix: return error or optional API and update uses; deps: hoist-remove-panics-and-a0d5efe0; verification: foundation tests
