---
title: Other backends
status: closed
priority: 3
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.995523+01:00\\\"\""
closed-at: "2026-02-06T17:42:36.686011+01:00"
close-reason: Wired riscv64/s390x lowering paths and fixed backend tests
blocks:
  - hoist-update-parity-docs-4f2077a3
---

File: src/codegen/compile.zig:4988-5002; cause: x64/riscv/s390x lowering/emit stubs; fix: implement or gate each backend; why: parity across targets.
