const std = @import("std");
const hoist = @import("hoist");
const legalize = hoist.legalize_types;
const Type = hoist.types.Type;

test "legalize_types module loads" {
    const legalizer = legalize.TypeLegalizer.default64();
    _ = legalizer;
}
