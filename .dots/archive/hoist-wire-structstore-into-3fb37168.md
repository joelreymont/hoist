---
title: Wire StructStore into abi.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:46.330675+01:00\""
closed-at: "2026-01-26T11:26:33.434710+01:00"
---

File: src/backends/aarch64/abi.zig
Add StructStore parameter to functions needing struct info:
- classifyArguments needs store param
- classifyReturn needs store param  
- Pass store from callers
Deps: hoist-add-type-getstructfields-e659214b
Verify: zig build test -Dtest-filter=abi
