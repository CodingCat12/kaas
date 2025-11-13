const std = @import("std");

pub const World = world.World;
pub const App = app.App;
pub const AppConfig = app.Config;
pub const Query = system.Query;
pub const Resource = system.Res;

pub const world = @import("world.zig");
pub const app = @import("app.zig");
pub const system = @import("system.zig");

pub const Entity = packed struct(u128) {
    storage_index: u64,
    list_index: u64,
};

pub fn Resources(comptime types: []const type) type {
    var fields: [types.len]std.builtin.Type.StructField = undefined;
    for (types, 0..) |T, i| {
        fields[i] = .{
            .name = @typeName(T),
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{ .@"struct" = .{
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
        .layout = .auto,
    } });
}
