---
title: Add Mach-O Section Emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.491093+01:00"
---

Context: src/object/macho.zig:179; cause: no load commands/sections/symtab; fix: emit LC_SEGMENT_64, symtab, strtab, relocs; deps: hoist-fix-mach-o-7a95266e; verification: otool -l + nm
