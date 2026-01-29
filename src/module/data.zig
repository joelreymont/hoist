const std = @import("std");
const Allocator = std.mem.Allocator;

const module = @import("module.zig");
const FuncId = module.FuncId;
const DataId = module.DataId;

/// Data init mode.
pub const Init = union(enum) {
    uninit,
    zeros: usize,
    bytes: []const u8,

    pub fn size(self: Init) !usize {
        return switch (self) {
            .uninit => error.UninitializedData,
            .zeros => |sz| sz,
            .bytes => |b| b.len,
        };
    }
};

/// Data target.
pub const DataTarget = union(enum) {
    func: FuncId,
    data: DataId,
    symbol: []const u8,
};

/// Data reloc.
pub const DataReloc = struct {
    offset: u32,
    target: DataTarget,
    addend: i64,
};

/// Data description.
pub const DataDesc = struct {
    init: Init,
    func_relocs: std.ArrayList(struct { offset: u32, func: FuncId }),
    data_relocs: std.ArrayList(DataReloc),
    @"align": ?u64,

    pub fn new(alloc: Allocator) DataDesc {
        _ = alloc;
        return .{
            .init = .uninit,
            .func_relocs = .{},
            .data_relocs = .{},
            .@"align" = null,
        };
    }

    pub fn deinit(self: *DataDesc, alloc: Allocator) void {
        self.func_relocs.deinit(alloc);
        self.data_relocs.deinit(alloc);
    }
};
