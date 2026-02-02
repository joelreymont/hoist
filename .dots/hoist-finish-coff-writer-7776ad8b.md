---
title: Finish COFF writer
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.869951+01:00"
blocks:
  - hoist-finish-elf-writer-03a39ee4
---

Context: src/object/coff.zig:162,193; cause: symbol index + section/symtab emission TODO; fix: implement section headers, symtab, string table; deps: none; verification: emit COFF and link with lld
