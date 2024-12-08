const std = @import("std");

const Spritesheet = @import("spritesheet.zig");
const Sprite = Spritesheet.Sprite;
const State = @This();

const Activity = enum {
    idle,
};

activity: Activity = .idle,

pub fn get_sprite(state: State) Spritesheet.Sprite {
    const sprite_index = @divFloor(std.time.milliTimestamp(), std.time.ms_per_s);

    const packed_offset: u12 = @intCast(switch (state.activity) {
        .idle => 0x000 + @abs(@mod(sprite_index, 4) - 2),
    });

    return Sprite.from_packed_offset(packed_offset);
}
