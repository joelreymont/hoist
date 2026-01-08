---
title: Add test with real external function call
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T22:32:12.591618+02:00"
---

File: tests/e2e_jit.zig. Create test that: registers external function 'test_external' with FuncRef system, builds IR with try_call to that function, compiles through full pipeline, verifies BL instruction emitted. Can't actually call without implementing full exception ABI, but tests lowering path. Depends on hoist-79f37c2060d59acc. ~20 min.
