---
title: ISLE const_prim typing
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T07:47:40.896216+01:00\\\"\""
closed-at: "2026-02-05T18:45:52.423158+01:00"
close-reason: Carry const_prim type_id; tests pass
---

src/dsl/isle/trie.zig + src/dsl/isle/codegen/emit_zig.zig + src/dsl/isle/codegen/match.zig; cause: trie.Binding/Constraint const_prim drop type_id so codegen emits enum literal (.I64) for Type constants; generated aarch64_lower_generated.zig fails (Type is packed struct); fix: carry type_id through const_prim, emit TypeName.Const for non-enum prim consts; proof: zig build test --global-cache-dir .zig-global-cache
