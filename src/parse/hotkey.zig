const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const hotkey_log = std.log.scoped(.Hotkey);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

var hotkey_test_buffer = [_]u8{
    0xFF, 0xFF, 0x00, 0x00,
    0x08, 0x00, 0x00, 0x00,
    0x20, 0x00, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0x0E, 0x00, 0x00, 0x00,
    0x7A, 0x01, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
    0xFF, 0xFF, 0x00, 0x00,
};

var mouse_test_buffer = [_]u8{
    0x18, 0x00, 0x00, 0x00,
    0x22, 0x00, 0x00, 0x00,
    0x23, 0x00, 0x00, 0x00,
    0x14, 0x00, 0x00, 0x00,
};

/// Size: 512
pub fn readHotkeys(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.hotkeys) and !is_test) {
        return error.BadStartingOffset;
    }
    var hotkeys = &parser.charsave.hotkeys;

    for (0..16) |i| {
        hotkeys[i].skill = try parser.readBits(u16, 16);
        hotkeys[i].item = try parser.readBits(u16, 16);
        if (main.log_hotkey) {
            hotkey_log.debug("Skill: {d}, Item: {d}", .{ hotkeys[i].skill, hotkeys[i].item });
        }
    }
}

test "hotkeys: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &hotkey_test_buffer;

    try readHotkeys(&parser);

    try expectEqual(0xFFFF, parser.charsave.hotkeys[0].skill);
    try expectEqual(8, parser.charsave.hotkeys[1].skill);
    try expectEqual(32, parser.charsave.hotkeys[2].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[3].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[4].skill);
    try expectEqual(14, parser.charsave.hotkeys[5].skill);
    try expectEqual(378, parser.charsave.hotkeys[6].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[7].skill);

    try expectEqual(0xFFFF, parser.charsave.hotkeys[8].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[9].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[10].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[11].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[12].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[13].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[14].skill);
    try expectEqual(0xFFFF, parser.charsave.hotkeys[15].skill);

    try expectEqual(0, parser.charsave.hotkeys[0].item);
    try expectEqual(0, parser.charsave.hotkeys[1].item);
    try expectEqual(0, parser.charsave.hotkeys[2].item);
    try expectEqual(0, parser.charsave.hotkeys[3].item);
    try expectEqual(0, parser.charsave.hotkeys[4].item);
    try expectEqual(0, parser.charsave.hotkeys[5].item);
    try expectEqual(0, parser.charsave.hotkeys[6].item);
    try expectEqual(0, parser.charsave.hotkeys[7].item);

    try expectEqual(0, parser.charsave.hotkeys[8].item);
    try expectEqual(0, parser.charsave.hotkeys[9].item);
    try expectEqual(0, parser.charsave.hotkeys[10].item);
    try expectEqual(0, parser.charsave.hotkeys[11].item);
    try expectEqual(0, parser.charsave.hotkeys[12].item);
    try expectEqual(0, parser.charsave.hotkeys[13].item);
    try expectEqual(0, parser.charsave.hotkeys[14].item);
    try expectEqual(0, parser.charsave.hotkeys[15].item);
}

/// Size: 128
pub fn readMouseSkills(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.mouse_skills) and !is_test) {
        return error.BadStartingOffset;
    }
    var mouse = &parser.charsave.mouse_skills;

    mouse.left.skill_id = try parser.readBits(u16, 16);
    mouse.left.item_index = try parser.readBits(u16, 16);
    mouse.right.skill_id = try parser.readBits(u16, 16);
    mouse.right.item_index = try parser.readBits(u16, 16);

    mouse.left_swap.skill_id = try parser.readBits(u16, 16);
    mouse.left_swap.item_index = try parser.readBits(u16, 16);
    mouse.right_swap.skill_id = try parser.readBits(u16, 16);
    mouse.right_swap.item_index = try parser.readBits(u16, 16);

    if (main.log_hotkey) {
        hotkey_log.debug("Left: {any}", .{mouse.left});
        hotkey_log.debug("Right: {any}", .{mouse.right});
        hotkey_log.debug("Left(swap): {any}", .{mouse.left_swap});
        hotkey_log.debug("Right(swap): {any}", .{mouse.right_swap});
    }
}

test "mouse skills: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &mouse_test_buffer;

    try readMouseSkills(&parser);

    try expectEqual(24, parser.charsave.mouse_skills.left.skill_id);
    try expectEqual(0, parser.charsave.mouse_skills.left.item_index);
    try expectEqual(34, parser.charsave.mouse_skills.right.skill_id);
    try expectEqual(0, parser.charsave.mouse_skills.right.item_index);

    try expectEqual(35, parser.charsave.mouse_skills.left_swap.skill_id);
    try expectEqual(0, parser.charsave.mouse_skills.left_swap.item_index);
    try expectEqual(20, parser.charsave.mouse_skills.right_swap.skill_id);
    try expectEqual(0, parser.charsave.mouse_skills.right_swap.item_index);
}

pub fn writeHotkeys(parser: *Parser) void {
    const hotkeys = &parser.charsave.hotkeys;
    for (0..16) |i| {
        parser.writeBits(16, hotkeys[i].skill);
        parser.writeBits(16, hotkeys[i].item);
    }
}

test "hotkeys: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var hotkeys = &parser.charsave.hotkeys;

    hotkeys[0].skill = 0xFFFF;
    hotkeys[1].skill = 8;
    hotkeys[2].skill = 32;
    hotkeys[3].skill = 0xFFFF;
    hotkeys[4].skill = 0xFFFF;
    hotkeys[5].skill = 14;
    hotkeys[6].skill = 378;
    hotkeys[7].skill = 0xFFFF;

    hotkeys[8].skill = 0xFFFF;
    hotkeys[9].skill = 0xFFFF;
    hotkeys[10].skill = 0xFFFF;
    hotkeys[11].skill = 0xFFFF;
    hotkeys[12].skill = 0xFFFF;
    hotkeys[13].skill = 0xFFFF;
    hotkeys[14].skill = 0xFFFF;
    hotkeys[15].skill = 0xFFFF;

    hotkeys[0].item = 0;
    hotkeys[1].item = 0;
    hotkeys[2].item = 0;
    hotkeys[3].item = 0;
    hotkeys[4].item = 0;
    hotkeys[5].item = 0;
    hotkeys[6].item = 0;
    hotkeys[7].item = 0;

    hotkeys[8].item = 0;
    hotkeys[9].item = 0;
    hotkeys[10].item = 0;
    hotkeys[11].item = 0;
    hotkeys[12].item = 0;
    hotkeys[13].item = 0;
    hotkeys[14].item = 0;
    hotkeys[15].item = 0;

    writeHotkeys(&parser);

    for (hotkey_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn writeMouseSkills(parser: *Parser) void {
    const mouse = &parser.charsave.mouse_skills;

    parser.writeBits(16, mouse.left.skill_id);
    parser.writeBits(16, mouse.left.item_index);
    parser.writeBits(16, mouse.right.skill_id);
    parser.writeBits(16, mouse.right.item_index);

    parser.writeBits(16, mouse.left_swap.skill_id);
    parser.writeBits(16, mouse.left_swap.item_index);
    parser.writeBits(16, mouse.right_swap.skill_id);
    parser.writeBits(16, mouse.right_swap.item_index);
}

test "mouse skills: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var mouse = &parser.charsave.mouse_skills;
    mouse.left.skill_id = 24;
    mouse.left.item_index = 0;
    mouse.right.skill_id = 34;
    mouse.right.item_index = 0;

    mouse.left_swap.skill_id = 35;
    mouse.left_swap.item_index = 0;
    mouse.right_swap.skill_id = 20;
    mouse.right_swap.item_index = 0;

    writeMouseSkills(&parser);

    for (mouse_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}
