---
title: Wire varargs flag
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T23:31:14.193301+01:00\""
closed-at: "2026-01-29T23:34:49.457300+01:00"
close-reason: completed
---

Context: src/ir/signature.zig:124, src/ir/text/parser.zig:123, src/machinst/abi.zig:199; cause: Signature.is_varargs is never set/propagated; fix: parse/print varargs in IR text, plumb to ABISignature/isle_helpers; deps: update printer tests; verification: new parser+printer tests and ABI varargs unit test.
