const std = @import("std");
const kaas = @import("kaas");

pub fn main() !void {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { x: f32, y: f32 };

    const Player = struct {
        pos: Position,
        vel: Velocity,
    };

    const Movement = struct {
        pub fn run(query: kaas.Query(struct { pos: *Position, vel: *const Velocity })) void {
            while (query.next()) |entry| {
                entry.pos.x += entry.vel.x;
                entry.pos.y += entry.vel.y;
            }
        }
    };

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var app: kaas.App(.{
        .archetypes = &.{Player},
        .systems = &.{Movement},
    }) = .init(allocator);
    defer app.deinit();

    const player = try app.world.spawn(Player, app.allocator, .{
        .pos = .{ .x = 0.2, .y = 37.5 },
        .vel = .{ .x = 10, .y = 0 },
    });

    const positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(positions);

    std.debug.print("Before applying velocity: {any}\n", .{positions});

    try app.run();

    const updated_positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(updated_positions);

    std.debug.print("After applying velocity: {any}\n", .{updated_positions});

    app.world.despawn(player);

    const empty_positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(empty_positions);

    std.debug.print("After despawning entites: {any}\n", .{empty_positions});
}
