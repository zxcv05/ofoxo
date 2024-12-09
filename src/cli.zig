const std = @import("std");

const Context = @import("context.zig");

const HELP_USAGE_FMT =
    \\ Usage: {s} [-p]
    \\
    \\ -h, --help       | Show this help message
    \\ -p, --primary    | Only run on primary display
;

pub inline fn show_help_usage(arg0: []const u8) void {
    const stderr = std.io.getStdErr();
    stderr.writer().print(HELP_USAGE_FMT, .{arg0}) catch {};
}

/// Returns whether main process can continue
/// Only returns false if show_help_usage called
pub fn parse_cli(alloc: std.mem.Allocator, ctx: *Context) !bool {
    var args = try std.process.ArgIterator.initWithAllocator(alloc);
    defer args.deinit();

    const arg0 = args.next().?;

    while (args.next()) |arg| {
        // --help -h
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            show_help_usage(arg0);
            return false;
        }
        // --output -o
        else if (std.mem.eql(u8, arg, "--primary") or std.mem.eql(u8, arg, "-p")) {
            ctx.primary_display_only = true;
        }
        // Not recognized
        else {
            return error.ArgumentNotRecognized;
        }
    }

    return true;
}
