const std = @import("std");

const Spritesheet = @import("spritesheet.zig");
const Sprite = Spritesheet.Sprite;
const State = @This();

pub const SPEED = 6;
pub const START_IDLE_RADIUS = 40;
pub const START_RUNNING_RADIUS = 160;
pub const SLEEP_TIME_THRESHOLD = 300;

pub const Activity = enum {
    idle,
    sleeping,
    running,
};

pub const Position = struct {
    x: isize,
    y: isize,
};

position: Position = .{ .x = 0, .y = 0 },
activity: Activity = .idle,
idle_time: usize = 0, // TODO: make non-frame dependent

pub fn update(this: *State, cursor: Position) void {
    const cross_x: f64 = @floatFromInt(cursor.x - this.position.x);
    const cross_y: f64 = @floatFromInt(cursor.y - this.position.y);
    const distance = @sqrt(cross_x * cross_x + cross_y * cross_y);

    // Change activity if needed
    if (this.activity == .running and distance < START_IDLE_RADIUS)
        this.activity = .idle
    else if (distance > START_RUNNING_RADIUS)
        this.activity = .running
    else if (this.idle_time > SLEEP_TIME_THRESHOLD)
        this.activity = .sleeping;

    // Move toward cursor
    if (this.activity == .running) {
        this.position.x += @intFromFloat(cross_x / distance * SPEED);
        this.position.y += @intFromFloat(cross_y / distance * SPEED);
    }

    if (this.activity == .idle) this.idle_time += 1 else this.idle_time = 0;
}

pub fn get_sprite(this: State) Spritesheet.Sprite {
    const timestamp = std.time.milliTimestamp();

    const packed_offset: u12 = @intCast(switch (this.activity) {
        .idle => 0x000 + @abs(@mod(@divFloor(timestamp, std.time.ms_per_s), 4) - 2),
        .sleeping => 0x000, // TODO: sleeping sprites
        // @mod(@divFloor(timestamp, std.time.ms_per_s / SPEED), number of running anims) + offset y of direction
        .running => 0x000, // TODO: running sprites
    });

    return Sprite.from_packed_offset(packed_offset);
}
