const std = @import("std");

pub const World = world.World;
pub const App = app.App;
pub const AppConfig = app.Config;
pub const Query = systems.Query;
pub const Resource = systems.Res;
pub const Module = @import("Module.zig");

pub const world = @import("world.zig");
pub const app = @import("app.zig");
pub const systems = @import("system.zig");

pub fn rootApp(allocator: std.mem.Allocator) RootApp() {
    return .init(allocator);
}

pub fn RootApp() type {
    return App(Module.init(@import("root")).build());
}

pub const Entity = packed struct(u128) {
    storage_index: u64,
    list_index: u64,
};
