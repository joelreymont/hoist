---
title: Add ELF Symtab/Strtab/Rela
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.587606+01:00"
blocks:
  - hoist-add-elf-section-d90d3c17
---

Context: src/object/elf.zig:191; cause: missing sym/str/rela sections; fix: emit symtab/strtab/shstrtab and rela sections; deps: Add ELF Section Layout; verification: llvm-readobj shows symbols+relocs
