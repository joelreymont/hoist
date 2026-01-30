---
title: Finish COFF writer
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:25:57.627719+01:00"
---

Context: src/object/coff.zig:162,193; cause: symbol index + section/symtab emission TODO; fix: implement section headers, symtab, string table; deps: none; verification: emit COFF and link with lld
