const std = @import("std");

const Function = @import("../../ir/function.zig").Function;
const Signature = @import("../../ir/signature.zig").Signature;
const Value = @import("../../ir/entities.zig").Value;
const types = @import("../../ir/types.zig");

const abi_mod = @import("abi.zig");

pub fn callStackMaxForArgs(
    allocator: std.mem.Allocator,
    func: *Function,
    sig: *const Signature,
    args: []const Value,
) !u32 {
    var arg_types = try allocator.alloc(types.Type, args.len);
    defer allocator.free(arg_types);

    for (args, 0..) |arg, idx| {
        arg_types[idx] = func.dfg.valueType(arg) orelse return error.MissingValueType;
    }

    var layout = try abi_mod.computeCallLayout(
        allocator,
        arg_types,
        sig,
        sig.call_conv,
        &func.struct_store,
    );
    defer layout.deinit(allocator);

    return layout.stack_size;
}
