---
title: Add NaN canonicalization pass
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:13.549915+02:00\""
closed-at: "2026-01-25T20:34:03.702594+02:00"
---

Create src/codegen/opts/nan_canon.zig. Insert canonical NaN after non-deterministic float ops. WebAssembly compliance. Deps: none. Verify: zig build test
