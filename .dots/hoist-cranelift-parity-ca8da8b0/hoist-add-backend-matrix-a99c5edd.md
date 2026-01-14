---
title: Add backend matrix
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.840310+02:00"
---

Files: build.zig:331-340
Root cause: tests only cover aarch64 paths.
Fix: add backend matrix tests for x64/riscv64/s390x.
Why: ensure multi-backend parity.
Deps: Add x64 tests, Add rv tests, Add s390 tests.
Verify: zig build test.
