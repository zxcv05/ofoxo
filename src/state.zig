const std = @import("std");

const Spritesheet = @import("spritesheet.zig");
const Sprite = Spritesheet.Sprite;
const State = @This();

pub const SPEED = 6;
pub const SLEEP_SEC_PER_FRAME = 5;

pub const WAKE_UP_RADIUS = 500;
pub const STOP_RUNNING_RADIUS = 25;
pub const START_RUNNING_RADIUS = 150;

pub const AWAKE_TIME_START_IDLE = 5 * std.time.ms_per_s;
pub const IDLE_TIME_SLEEP_THRESHOLD = 15 * std.time.ms_per_s;

pub const Activity = enum {
    idle,
    awake,
    running,
    sleeping,
};

pub const Direction = enum(u12) {
    north = 0x020,
    east = 0x030,
    south = 0x040,
    west = 0x050,
};

pub const Position = struct {
    x: isize,
    y: isize,
    dir: Direction = .north,
};

position: Position = .{ .x = 0, .y = 0 },
activity: Activity = .idle,
start_idle_ts: i64 = 0,
start_awake_ts: i64 = 0,

pub fn update(this: *State, cursor: Position) void {
    const timestamp = std.time.milliTimestamp();

    const cross_x: f64 = @floatFromInt(cursor.x - this.position.x);
    const cross_y: f64 = @floatFromInt(cursor.y - this.position.y);
    const distance = @sqrt(cross_x * cross_x + cross_y * cross_y);

    switch (this.activity) {
        .running => if (distance < STOP_RUNNING_RADIUS) {
            this.activity = .idle;
            this.start_idle_ts = timestamp;
        },
        .idle => if (distance > START_RUNNING_RADIUS) {
            this.activity = .running;
        } else if (timestamp > this.start_idle_ts + IDLE_TIME_SLEEP_THRESHOLD) {
            this.activity = .sleeping;
        },
        .sleeping => if (distance > WAKE_UP_RADIUS) {
            this.activity = .awake;
            this.start_awake_ts = timestamp;
        },
        .awake => if (timestamp > this.start_awake_ts + AWAKE_TIME_START_IDLE) {
            this.activity = .idle;
        },
    }

    // Move toward cursor
    if (this.activity == .running) {
        const delta_x: isize = @intFromFloat(cross_x / distance * SPEED);
        const delta_y: isize = @intFromFloat(cross_y / distance * SPEED);

        this.position.x += delta_x;
        this.position.y += delta_y;

        this.position.dir = if (@abs(delta_x) > @abs(delta_y))
            if (delta_x > 0) .east else .west
        else if (delta_y < 0) .north else .south;
    }
}

pub fn get_sprite(this: State) Spritesheet.Sprite {
    const timestamp = std.time.milliTimestamp();

    const packed_offset: u12 = @intCast(switch (this.activity) {
        .idle, .awake => 0x000 + @abs(@mod(@divFloor(timestamp, std.time.ms_per_s), 4) - 2),
        .sleeping => 0x070 + @mod(@divFloor(@abs(timestamp), std.time.ms_per_s * SLEEP_SEC_PER_FRAME), 4),
        .running => @intFromEnum(this.position.dir) +
            @mod(@divFloor(@abs(timestamp), std.time.ms_per_s / SPEED), 4),
    });

    return Sprite.from_packed_offset(packed_offset);
}
