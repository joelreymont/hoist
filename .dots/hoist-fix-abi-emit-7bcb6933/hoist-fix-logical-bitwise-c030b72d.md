---
title: Fix logical bitwise enc
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T13:02:31.521273+02:00"
---

Files: src/backends/aarch64/emit.zig:1210, src/backends/aarch64/emit.zig:1351, src/backends/aarch64/emit.zig:13039, src/backends/aarch64/emit.zig:1497, src/backends/aarch64/emit.zig:5520. Root cause: logical shifted-register encoding uses wrong bit placement (<<21) and NOT variants miss N bit. Fix: add helper to encode logical-shifted ops with opc/N/shift/imm6 fields; rewire AND/ORR/EOR/BIC/ORN/EON/MVN/TST to helper; update expected encodings in emit.zig tests. Verify: zig build test --cache-dir /tmp/zig-cache-hoist --global-cache-dir /tmp/zig-global-cache-hoist.
