---
title: Wire vmctx reg
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:27:07.405269+01:00"
---

Context: src/backends/aarch64/isle_impl.zig:1352; cause: vmctx register TODO; fix: fetch vmctx reg from ABI/ctx and thread through lowering; deps: ABI vmctx definition; verification: add vmctx tests + zig build test
