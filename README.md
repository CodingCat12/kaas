# kaas

`kaas` is an ECS (**E**ntity, **C**omponent, **S**ystem) library implemented in Zig with **zero runtime type knowledge**. This means that all type dispatch happens at compile time

## Philosophy

Many ECS libraries such as [Bevy](https://bevyengine.org) heavily rely on runtime type identification internally. While this allows for a lot of flexibility, it may limit performance. This, combined with the fact that in most cases, memory layout could very well be compile time-known, there could be lots of wasted space and time. `kaas` attempts to fix by making the types of all archetypes, resources and more fully handled at compile time, through a single `AppConfig` struct. The main idea is that anything that is registered at compile time should also be processed at compile time.

## Example usage

### World

```zig
const kaas = @import("kaas");

const Position = struct { x: f32, y: f32 };
const Velocity = struct { x: f32, y: f32 };

const Player = struct {
    pos: Position,
    vel: Velocity,
};

const Spike = struct { position: Position };

const allocator = std.heap.page_allocator;

var world = kaas.World(&.{
    Player,
    Spike,
}) = .empty;

_ = try world.spawn(Player, allocator, .{
    .pos = .{ .x = 0, .y = 0 },
    .vel = .{ .x = 0, .y = 5 },
});

_ = try world.spawn(Spike, allocator, .{
    .position = .{ .x = 10, .y = 4.5 },
});

const positions = try world.query(struct { *const Position }, allocator);
defer allocator.free(positions);

for (positions, 1..) |item, i| {
    const pos = item.@"0".*;
    std.debug.print("{d}. x: {d.:2}, y: {d.:2}", .{i, pos.x, pos.y});
}
```

Output:

```
1. x: 0.00, y: 0.00
2. x: 10.00, y: 4.50
```

### App

TODO
