---
title: Resolve inliner callees
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:47.717279+01:00"
---

Context: src/codegen/opts/inliner.zig:292; cause: callee resolution TODO; fix: map call instruction to callee func and inline when eligible; deps: call graph access; verification: add inliner tests + zig build test
