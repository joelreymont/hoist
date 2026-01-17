---
title: Add NaN canonicalization pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:13.549915+02:00"
---

Create src/codegen/opts/nan_canon.zig. Insert canonical NaN after non-deterministic float ops. WebAssembly compliance. Deps: none. Verify: zig build test
