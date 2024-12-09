const std = @import("std");
const zgl = @import("zgl");
const zimg = @import("zimg");

pub const Spritesheet = @This();

pub const Sprite = struct {
    pub const width = 32;
    pub const height = 32;

    x: usize,
    y: usize,

    pub inline fn from_packed_offset(definition: u8) Sprite {
        const x = (definition & 0x00f) >> 0;
        const y = (definition & 0x0f0) >> 4;
        return Sprite{
            .x = x * Sprite.width,
            .y = y * Sprite.height,
        };
    }
};

texture: zgl.Texture,
image: zimg.ImageUnmanaged,

pub fn from_embedded(allocator: std.mem.Allocator, data: [:0]const u8) !Spritesheet {
    const image = try zimg.ImageUnmanaged.fromMemory(allocator, data[0..]);
    const texture = zgl.genTexture();
    texture.bind(.@"2d");

    zgl.textureImage2D(
        .@"2d",
        0,
        .rgba8,
        image.width,
        image.height,
        .rgba,
        .unsigned_byte,
        @ptrCast(image.pixels.rgba32.ptr),
    );

    return Spritesheet{
        .texture = texture,
        .image = image,
    };
}

pub fn deinit(this: *Spritesheet, allocator: std.mem.Allocator) void {
    this.texture.delete();
    this.image.deinit(allocator);
}
