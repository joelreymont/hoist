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

    pub fn size(self: Init) usize {
        return switch (self) {
            .uninit => @panic("uninit data size"),
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
    align: ?u64,

    pub fn new(alloc: Allocator) DataDesc {
        return .{
            .init = .uninit,
            .func_relocs = std.ArrayList(@TypeOf(.{ .offset = 0, .func = FuncId.from(0) })).init(alloc),
            .data_relocs = std.ArrayList(DataReloc).init(alloc),
            .align = null,
        };
    }

    pub fn deinit(self: *DataDesc) void {
        self.func_relocs.deinit();
        self.data_relocs.deinit();
    }
};
