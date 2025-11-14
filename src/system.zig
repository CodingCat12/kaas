const std = @import("std");

pub const Schedule = enum { startup, update };

pub fn Res(comptime T: type) type {
    return struct {
        ptr: *T,

        pub const Child = T;

        pub const __kaas_res: void = {};
    };
}

pub fn Query(comptime T: type) type {
    return struct {
        ptr: *Inner,

        const Self = @This();

        pub const Data = T;

        pub const __kaas_query: void = {};

        pub fn next(self: Self) ?T {
            if (self.ptr.index >= self.ptr.slice.len) return null;
            defer self.ptr.index += 1;
            return self.ptr.slice[self.ptr.index];
        }

        pub const Inner = struct {
            slice: []const T,
            index: usize = 0,
        };
    };
}

pub fn World(comptime T: type) type {
    return struct {
        ptr: *T,

        pub const Child = T;

        pub const __kaas_world: void = {};
    };
}

pub fn callSystem(
    comptime System: type,
    allocator: std.mem.Allocator,
    world: anytype,
    resources: anytype,
) !void {
    const runFn = System.run;
    const RunFn = @TypeOf(runFn);

    const Args = std.meta.ArgsTuple(RunFn);

    var args: Args = undefined;

    inline for (std.meta.fields(Args)) |field| {
        const Field = field.type;

        if (@hasDecl(Field, "__kaas_query")) {
            const slice = try world.query(Field.Data, allocator);
            var inner = Field.Inner{ .slice = slice };
            @field(args, field.name).ptr = &inner;
        }

        if (@hasDecl(Field, "__kaas_res")) {
            @field(args, field.name).ptr = &@field(resources, @typeName(Field.Child));
        }

        if (@hasDecl(Field, "__kaas_world")) {
            @field(args, field.name).ptr = world;
        }

        if (Field == std.mem.Allocator) {
            @field(args, field.name) = allocator;
        }
    }

    defer inline for (@typeInfo(Args).@"struct".fields) |field| {
        if (@hasDecl(@FieldType(Args, field.name), "__kaas_query")) {
            allocator.free(@field(args, field.name).ptr.slice);
        }
    };

    const res = @call(.auto, runFn, args);

    if (@typeInfo(@typeInfo(RunFn).@"fn".return_type.?) == .error_union) try res;
}
