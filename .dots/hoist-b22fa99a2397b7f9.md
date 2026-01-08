---
title: Add landing pad test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:07:39.742888+02:00"
---

File: tests/e2e_jit.zig. Create try_call test with catch block. Verify CFG has exception edge. Check landing pad block is reachable. Verify exception value (X0) accessible in handler. Basic infrastructure test. ~20 min.
