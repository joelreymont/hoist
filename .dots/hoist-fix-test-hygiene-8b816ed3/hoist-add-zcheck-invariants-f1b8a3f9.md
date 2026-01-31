---
title: Add Zcheck Invariants
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.590454+01:00\""
closed-at: "2026-01-31T20:28:46.040324+01:00"
---

Context: src/backends/aarch64/zcheck_properties.zig:1; cause: missing invariants for new behaviors; fix: add zcheck properties for JIT alloc and tailcall moves; deps: hoist-fix-test-hygiene-8b816ed3; verification: zig build test -- zcheck
