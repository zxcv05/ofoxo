const std = @import("std");

const Spritesheet = @import("spritesheet.zig");
const Sprite = Spritesheet.Sprite;
const State = @This();

pub const SPEED = 6;
pub const SLEEP_SEC_PER_FRAME = 5;

pub const WAKE_UP_RADIUS = 500;
pub const STOP_RUNNING_RADIUS = 25;
pub const START_RUNNING_RADIUS = 150;

pub const SPRITE_TIME_ALLOW_CHANGE = 125;
pub const AWAKE_TIME_START_IDLE = 5 * std.time.ms_per_s;
pub const IDLE_TIME_START_SLEEP = 15 * std.time.ms_per_s;

pub const Activity = enum {
    idle,
    awake,
    running,
    sleeping,
};

pub const Direction = enum(u8) {
    north = 0x20,
    east = 0x30,
    south = 0x40,
    west = 0x50,
};

pub const Position = struct {
    x: isize,
    y: isize,
    dir: Direction = .north,
};

position: Position = .{ .x = 0, .y = 0 },
sprite: u8 = 0x00,

activity: Activity = .idle,
start_idle_ts: i64 = 0,
start_awake_ts: i64 = 0,
sprite_change_ts: i64 = 0,

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
        } else if (timestamp > this.start_idle_ts + IDLE_TIME_START_SLEEP) {
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

    const new_sprite: u8 = @intCast(switch (this.activity) {
        .idle, .awake => 0x00 + @abs(@mod(@divFloor(timestamp, std.time.ms_per_s), 4) - 2),
        .sleeping => 0x70 + @mod(@divFloor(@abs(timestamp), std.time.ms_per_s * SLEEP_SEC_PER_FRAME), 4),
        .running => @intFromEnum(this.position.dir) +
            @mod(@divFloor(@abs(timestamp), std.time.ms_per_s / SPEED), 4),
    });

    if (new_sprite != this.sprite and timestamp > this.sprite_change_ts + SPRITE_TIME_ALLOW_CHANGE) {
        this.sprite = new_sprite;
        this.sprite_change_ts = timestamp;
    }
}

pub fn get_sprite(this: State) Spritesheet.Sprite {
    return Sprite.from_packed_offset(this.sprite);
}
