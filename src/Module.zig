const kaas = @import("root.zig");

bundles: []const type = &.{},
systems: []const type = &.{},
resources: []const type = &.{},

const Self = @This();

pub const empty: Self = .{};

pub fn init(comptime M: type) Self {
    var self: Self = .empty;
    self.import(M);
    return self;
}

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

pub fn addResource(self: *Self, comptime T: type) void {
    self.resources = self.resources ++ .{T};
}

pub fn addResources(self: *Self, comptime resources: anytype) void {
    self.resources = self.resources ++ resources;
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
        .resources = self.resources,
    };
}
