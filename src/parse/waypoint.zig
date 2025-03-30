const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const waypoint_log = std.log.scoped(.Waypoint);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

var map_test_buffer = [_]u8{
    0x00, 0x00, 0x80, 0xDD, 0xBB, 0x08, 0x3E,
};

var waypoint_test_buffer = [_]u8{
    0x57, 0x53, 0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x02, 0x01, 0xA7, 0x6B, 0xBF, 0xFE, 0x77, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x02, 0x01, 0xA7, 0x46, 0xAF, 0xFA, 0x62, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0xFF, 0x7F, 0xFF, 0xFF, 0x7F, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

/// Size: 56
pub fn readMapInfo(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.map_info) and !is_test) {
        return error.BadStartingOffset;
    }

    for (0..3) |i| {
        parser.charsave.town[i] = @bitCast(try parser.readBits(u8, 8));
    }

    parser.charsave.map_seed = try parser.readBits(u32, 32);
    if (main.log_waypoint) {
        waypoint_log.debug("\n  {any}\n  {any}\n  {any}", .{
            parser.charsave.town[0],
            parser.charsave.town[1],
            parser.charsave.town[2],
        });
        waypoint_log.debug("MAP_ID: {d}", .{parser.charsave.map_seed});
    }
}

test "mapinfo: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &map_test_buffer;

    try readMapInfo(&parser);

    try expectEqual(0, parser.charsave.town[0]);
    try expectEqual(0, parser.charsave.town[1]);
    try expectEqual(128, parser.charsave.town[2]);
    try expectEqual(1040759773, parser.charsave.map_seed);
}

/// Size: 640
pub fn readWaypoint(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.waypoint) and !is_test) {
        return error.BadStartingOffset;
    }

    var waypoint = &parser.charsave.waypoint_data;

    waypoint.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(waypoint.identifier, .waypoint);
    waypoint.unknown_635 = try parser.readBits(u32, 32);
    waypoint.size = try parser.readBits(u16, 16);

    if (main.log_waypoint) {
        waypoint_log.debug("Size: {d}, Unknown: {d}", .{ waypoint.size, waypoint.unknown_635 });
    }

    for (0..3) |i| {
        waypoint.waypoints[i] = @bitCast((try parser.readBits(u192, 192)));
    }
}

test "waypoint: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &waypoint_test_buffer;

    try readWaypoint(&parser);

    const flags_norm = [_]u16{ 258, 27559, 65215, 119, 0, 0, 0, 0 };
    const flags_nigt = [_]u16{ 258, 18087, 64175, 98, 0, 0, 0, 0 };
    const flags_hell = [_]u16{ 258, 32767, 65535, 127, 0, 0, 0, 0 };

    try expectEqual(@intFromEnum(SaveIdentifiers.waypoint), parser.charsave.waypoint_data.identifier);
    try expectEqual(1, parser.charsave.waypoint_data.unknown_635);
    try expectEqual(80, parser.charsave.waypoint_data.size);

    try expectEqual(flags_norm, parser.charsave.waypoint_data.waypoints[0].flags);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[0].unknown_1);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[0].unknown_2);

    try expectEqual(flags_nigt, parser.charsave.waypoint_data.waypoints[1].flags);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[1].unknown_1);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[1].unknown_2);

    try expectEqual(flags_hell, parser.charsave.waypoint_data.waypoints[2].flags);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[2].unknown_1);
    try expectEqual(0, parser.charsave.waypoint_data.waypoints[2].unknown_2);
}

pub fn writeMapInfo(parser: *Parser) !void {
    if (parser.out_offset != @intFromEnum(StartOffset.map_info) and !is_test) {
        return error.BadStartingOffset;
    }

    for (0..3) |i| {
        parser.writeBits(8, @as(u8, @bitCast(parser.charsave.town[i])));
    }
    parser.writeBits(32, parser.charsave.map_seed);
}

test "mapinfo: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.charsave.town[0] = 0;
    parser.charsave.town[1] = 0;
    parser.charsave.town[2] = 128;
    parser.charsave.map_seed = 1040759773;

    writeMapInfo(&parser);

    for (map_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn writeWaypoint(parser: *Parser) !void {
    if (parser.out_offset != @intFromEnum(StartOffset.waypoint) and !is_test) {
        return error.BadStartingOffset;
    }
    const waypoint = &parser.charsave.waypoint_data;

    parser.writeBits(16, waypoint.identifier);
    parser.writeBits(32, waypoint.unknown_635);
    parser.writeBits(16, waypoint.size);

    for (0..3) |i| {
        parser.writeBits(192, @as(u192, @bitCast(waypoint.waypoints[i])));
    }
}

test "waypoint: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var waypoint = &parser.charsave.waypoint_data;
    waypoint.identifier = @intFromEnum(SaveIdentifiers.waypoint);
    waypoint.unknown_635 = 1;
    waypoint.size = 80;

    waypoint.waypoints[0].flags = [_]u16{ 258, 27559, 65215, 119, 0, 0, 0, 0 };
    waypoint.waypoints[0].unknown_1 = 0;
    waypoint.waypoints[0].unknown_2 = 0;

    waypoint.waypoints[1].flags = [_]u16{ 258, 18087, 64175, 98, 0, 0, 0, 0 };
    waypoint.waypoints[1].unknown_1 = 0;
    waypoint.waypoints[1].unknown_2 = 0;

    waypoint.waypoints[2].flags = [_]u16{ 258, 32767, 65535, 127, 0, 0, 0, 0 };
    waypoint.waypoints[2].unknown_1 = 0;
    waypoint.waypoints[2].unknown_2 = 0;

    writeWaypoint(&parser);

    for (waypoint_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}
