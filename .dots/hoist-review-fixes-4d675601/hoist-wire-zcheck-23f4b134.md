---
title: Wire zcheck
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.940253+02:00\\\"\""
closed-at: "2026-01-17T13:25:25.709899+02:00"
---

Files: src/root.zig:126-134, src/backends/aarch64/zcheck_properties.zig:1. Cause: zcheck properties not imported into tests. Fix: add test import so zig build test runs zcheck properties. Why: property coverage. Verify: zig build test (or zig test src/backends/aarch64/zcheck_properties.zig).
