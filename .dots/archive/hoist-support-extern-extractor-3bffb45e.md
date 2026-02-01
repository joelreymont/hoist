---
title: Support extern extractor bindings
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T21:40:28.413053+01:00\\\"\""
closed-at: "2026-02-01T18:26:45.312804+01:00"
close-reason: "completed: extractor bindings use parameter slices (src/dsl/isle/trie.zig:54-58), extern extractor patterns compiled (src/dsl/isle/codegen/match.zig:313-428) with tuple field bindings, expressions wire extractor params (src/dsl/isle/codegen/match.zig:455-469), and codegen calls extractor with all params (src/dsl/isle/codegen/constructors.zig:341-349)"
---

Context: src/dsl/isle/trie.zig:55, src/dsl/isle/codegen/match.zig:88/376, src/dsl/isle/codegen/constructors.zig:282; cause: extractor binding limited to one param and extern extractors aren't compiled in patterns/if-let; fix: add extractor parameters slice, compile extern extractor patterns/exprs, emit tuple field bindings, update codegen to call extractor with all params; deps: hoist-add-partial-decl-6b17700a; verification: NO_COLOR=1 zig build test
