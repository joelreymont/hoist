//! Dynamic IR types.
//!
//! Ported from cranelift-codegen ir/dynamic_type.rs.
//! Dynamic types have a base vector type and a scaling factor from a GlobalValue.

const std = @import("std");
const Type = @import("types.zig").Type;
const GlobalValue = @import("entities.zig").GlobalValue;
const PrimaryMap = @import("../foundation/maps.zig").PrimaryMap;
const entities = @import("entities.zig");
const DynamicType = entities.DynamicType;

/// A dynamic type object which has a base vector type and a scaling factor.
pub const DynamicTypeData = struct {
    /// Base vector type, this is the minimum size of the type.
    base_vector_ty: Type,
    /// The dynamic scaling factor of the base vector type.
    dynamic_scale: GlobalValue,

    /// Create a new dynamic type.
    pub fn init(base_vector_ty: Type, dynamic_scale: GlobalValue) DynamicTypeData {
        std.debug.assert(base_vector_ty.isVector());
        return .{
            .base_vector_ty = base_vector_ty,
            .dynamic_scale = dynamic_scale,
        };
    }

    /// Convert 'base_vector_ty' into a concrete dynamic vector type.
    pub fn concrete(self: *const DynamicTypeData) ?Type {
        return self.base_vector_ty.vectorToDynamic();
    }
};

/// All allocated dynamic types.
pub const DynamicTypes = PrimaryMap(DynamicType, DynamicTypeData);

const testing = std.testing;

test "DynamicTypeData basic" {
    const gv = GlobalValue.fromIndex(0);
    const base_ty = Type.I32X4;

    const dt = DynamicTypeData.init(base_ty, gv);
    try testing.expect(dt.base_vector_ty.eql(Type.I32X4));
    try testing.expectEqual(gv, dt.dynamic_scale);
}
