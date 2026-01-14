---
title: Fix sysv reg list lifetime
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T13:02:58.244960+02:00"
---

Files: src/machinst/abi.zig:525. Root cause: sysv_amd64 returns slices to function-local arrays; after return they point at overwritten stack (float args read as callee-saves). Fix: move int/float arg/ret and callee-save arrays to file-scope consts, return slices to those constants. Verify: machinst.abi vector argument allocation test passes.
