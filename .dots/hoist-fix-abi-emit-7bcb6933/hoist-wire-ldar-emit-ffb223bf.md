---
title: Wire ldar emit
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T13:02:37.511948+02:00"
---

Files: src/backends/aarch64/emit.zig:150, src/backends/aarch64/emit.zig:2577, src/backends/aarch64/emit.zig:2638, src/backends/aarch64/isle_helpers.zig:724. Root cause: emit switch missing .ldar case and LDAR encoders set o0 bit; isle helper uses wrong field name. Fix: add .ldar case selecting emitLdarW/X by size; clear bit21 per LDAR encoding; change .addr -> .base in isle_helpers. Verify: emit ldar_* tests in src/backends/aarch64/emit.zig:8935 and zig build test.
