const kaas = @import("root.zig");

bundles: []const type = &.{},
systems: []const type = &.{},

const Self = @This();

pub const init: Self = .{};

pub fn addBundle(self: *Self, comptime T: type) void {
    self.bundles = self.bundles ++ .{T};
}

pub fn addBundles(self: *Self, comptime bundles: anytype) void {
    self.bundles = self.bundles ++ bundles;
}

pub fn addSystem(self: *Self, comptime T: type) void {
    self.systems = self.systems ++ .{T};
}

pub fn addSystems(self: *Self, comptime systems: anytype) void {
    self.systems = self.systems ++ systems;
}

pub fn import(self: *Self, comptime M: type) void {
    M.module(self);
}

pub fn World(self: *const Self) type {
    return kaas.World(self.bundles);
}

pub fn build(self: Self) kaas.AppConfig {
    return .{
        .systems = self.systems,
        .archetypes = self.bundles,
        .resources = &.{},
    };
}
