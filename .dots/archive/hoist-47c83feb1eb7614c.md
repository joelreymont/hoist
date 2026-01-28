---
title: Fix test compilation errors in machinst/lower.zig
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T10:40:51.668675+02:00"
closed-at: "2026-01-07T10:42:01.456341+02:00"
---

Error: Files accessing root.function, root.entities, root.signature fail when compiled as tests because root becomes test_runner.

Files affected: src/machinst/lower.zig (89 compilation errors)

Root cause: These files use @import("../root.zig") as root, but in test context, root is the test runner not the actual root module.

Solution: Import modules directly instead of through root, or conditionally import based on build mode.

Impact: Blocks running . E2E tests that import hoist module should still work through build system.

Priority: Medium - doesn't block manual testing via build system, but breaks automated test suite.
