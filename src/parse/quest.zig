const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const quest_log = std.log.scoped(.Quest);
const npc_log = std.log.scoped(.Npc);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

var quest_test_buffer = [_]u8{
    0x57, 0x6F, 0x6F, 0x21, 0x06, 0x00, 0x00, 0x00, 0x2A, 0x01, 0x01, 0x00, 0x01, 0x10, 0x1C, 0x00,
    0x49, 0x10, 0x00, 0x00, 0x04, 0x00, 0x19, 0x10, 0x01, 0x00, 0x01, 0x00, 0x11, 0x10, 0x01, 0x18,
    0x05, 0x10, 0x81, 0x11, 0x05, 0x10, 0x25, 0x10, 0x01, 0x00, 0x01, 0x00, 0x01, 0x10, 0x1D, 0x10,
    0xF5, 0x13, 0x01, 0x10, 0x1D, 0x10, 0x61, 0x18, 0x01, 0x00, 0x01, 0x00, 0x01, 0x10, 0x01, 0x13,
    0x2C, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x22, 0x80, 0x01, 0x10, 0x89, 0x17, 0x0C, 0x00, 0x39, 0x10, 0x5D, 0x16, 0x02, 0x80, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x10, 0x0C, 0x00,
    0x49, 0x80, 0x00, 0x00, 0x00, 0x00, 0x19, 0x10, 0x01, 0x00, 0x01, 0x00, 0x11, 0x10, 0x79, 0x1C,
    0x05, 0x10, 0x81, 0x11, 0x05, 0x00, 0x25, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x85, 0x00,
    0xF5, 0x03, 0x01, 0x00, 0x09, 0x00, 0x61, 0x08, 0x01, 0x00, 0x01, 0x00, 0x01, 0x10, 0x01, 0x13,
    0x01, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x22, 0x80, 0x01, 0x90, 0x8A, 0x81, 0x00, 0x00, 0x39, 0x10, 0x11, 0x04, 0x02, 0x80, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x10, 0x1D, 0x10,
    0x49, 0x90, 0x19, 0x14, 0x15, 0x10, 0x19, 0x10, 0x01, 0x00, 0x01, 0x00, 0x11, 0x10, 0x79, 0x1C,
    0x05, 0x10, 0x81, 0x11, 0x05, 0x10, 0x25, 0x10, 0x01, 0x00, 0x01, 0x00, 0x01, 0x10, 0x05, 0x10,
    0xF5, 0x13, 0x01, 0x10, 0x19, 0x10, 0x61, 0x10, 0x01, 0x00, 0x01, 0x00, 0x01, 0x10, 0x01, 0x13,
    0x01, 0x90, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x21, 0x80, 0x08, 0x00, 0x89, 0x97, 0x0C, 0x00, 0x19, 0x10, 0x5D, 0x17, 0x02, 0x80, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

var npc_test_buffer = [_]u8{
    0x01, 0x77, 0x34, 0x00,
    0xAE, 0xAE, 0xA5, 0xC9,
    0x06, 0x00, 0x00, 0x00,
    0xAC, 0x24, 0xA4, 0x89,
    0x06, 0x00, 0x00, 0x00,
    0xAE, 0xAE, 0xA4, 0xC9,
    0x06, 0x00, 0x00, 0x00,
    0xC0, 0x7F, 0xE7, 0x19,
    0x00, 0x00, 0x00, 0x00,
    0xFE, 0xFF, 0xE7, 0x19,
    0x00, 0x00, 0x00, 0x00,
    0x80, 0xF8, 0xE1, 0x18,
    0x00, 0x00, 0x00, 0x00,
};

/// Size: 2384
pub fn readQuest(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.quest) and !is_test) {
        return error.BadStartingOffset;
    }

    var quest = &parser.charsave.quest_data;
    quest.identifier = try parser.readBits(u32, 32);
    try verifyIdentifier(quest.identifier, .quest);
    quest.version = try parser.readBits(u32, 32);
    quest.size = try parser.readBits(u16, 16);
    if (quest.size != 298) {
        return error.InvalidQuestSize;
    }

    for (0..3) |i| {
        quest.quests[i] = @bitCast(try parser.readBits(u768, 768));
    }
}

test "Quest: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &quest_test_buffer;

    try readQuest(&parser);

    const quest_norm = [_]u16{
        1,    4097,  28,   4169,  0,    4,    4121, 1,
        1,    4113,  6145, 4101,  4481, 4101, 4133, 1,
        1,    4097,  4125, 5109,  4097, 4125, 6241, 1,
        1,    4097,  4865, 44,    1,    0,    0,    0,
        0,    0,     0,    32802, 4097, 6025, 12,   4153,
        5725, 32770, 0,    0,     0,    0,    0,    0,
    };
    const quest_nigt = [_]u16{
        1,    4097,  12,   32841, 0,     0,     4121, 1,
        1,    4113,  7289, 4101,  4481,  5,     37,   1,
        1,    1,     133,  1013,  1,     9,     2145, 1,
        1,    4097,  4865, 4097,  1,     0,     0,    0,
        1,    0,     0,    32802, 36865, 33162, 0,    4153,
        1041, 32770, 0,    0,     0,     0,     0,    0,
    };
    const quest_hell = [_]u16{
        1,    4097,  4125, 36937, 5145, 4117,  4121, 1,
        1,    4113,  7289, 4101,  4481, 4101,  4133, 1,
        1,    4097,  4101, 5109,  4097, 4121,  4193, 1,
        1,    4097,  4865, 36865, 1,    0,     0,    0,
        1,    0,     0,    32801, 8,    38793, 12,   4121,
        5981, 32770, 0,    0,     0,    0,     0,    0,
    };

    try expectEqual(@intFromEnum(SaveIdentifiers.quest), parser.charsave.quest_data.identifier);
    try expectEqual(6, parser.charsave.quest_data.version);
    try expectEqual(298, parser.charsave.quest_data.size);

    try expectEqual(quest_norm, parser.charsave.quest_data.quests_temp1);
    try expectEqual(quest_nigt, parser.charsave.quest_data.quests_temp2);
    try expectEqual(quest_hell, parser.charsave.quest_data.quests_temp3);
}

/// Size: 416
pub fn readNPCIntro(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.npc_intro) and !is_test) {
        return error.BadStartingOffset;
    }

    var npc = &parser.charsave.npc_data;
    npc.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(npc.identifier, .npc);
    npc.size = try parser.readBits(u16, 16);
    if (npc.size != 52) {
        return error.InvalidNPCSize;
    }
    if (main.log_quest) {
        npc_log.debug("Size: {d}", .{npc.size});
    }

    for (0..3) |i| {
        npc.quest_intro[i] = @bitCast(try parser.readBits(u64, 64));
        if (main.log_quest) {
            npc_log.debug("NPC Q: {any}", .{npc.quest_intro[i]});
        }
    }
    for (0..3) |i| {
        npc.npc_intro[i] = @bitCast(try parser.readBits(u64, 64));
        if (main.log_quest) {
            npc_log.debug("NPC I: {any}", .{npc.npc_intro[i]});
        }
    }
}

test "NPC Intro: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &npc_test_buffer;

    try readNPCIntro(&parser);

    const quest_norm = [_]u8{ 174, 174, 165, 201, 6, 0, 0, 0 };
    const quest_nigt = [_]u8{ 172, 36, 164, 137, 6, 0, 0, 0 };
    const quest_hell = [_]u8{ 174, 174, 164, 201, 6, 0, 0, 0 };
    const npc_norm = [_]u8{ 192, 127, 231, 25, 0, 0, 0, 0 };
    const npc_nigt = [_]u8{ 254, 255, 231, 25, 0, 0, 0, 0 };
    const npc_hell = [_]u8{ 128, 248, 225, 24, 0, 0, 0, 0 };

    try expectEqual(@intFromEnum(SaveIdentifiers.npc), parser.charsave.npc_data.identifier);
    try expectEqual(52, parser.charsave.npc_data.size);

    try expectEqual(quest_norm, parser.charsave.npc_data.quest_intro[0].temp);
    try expectEqual(quest_nigt, parser.charsave.npc_data.quest_intro[1].temp);
    try expectEqual(quest_hell, parser.charsave.npc_data.quest_intro[2].temp);
    try expectEqual(npc_norm, parser.charsave.npc_data.npc_intro[0].temp);
    try expectEqual(npc_nigt, parser.charsave.npc_data.npc_intro[1].temp);
    try expectEqual(npc_hell, parser.charsave.npc_data.npc_intro[2].temp);
}

pub fn writeQuest(parser: *Parser) !void {
    if (parser.out_offset != @intFromEnum(StartOffset.quest) and !is_test) {
        return error.BadStartingOffset;
    }

    const quest = &parser.charsave.quest_data;
    parser.writeBits(32, quest.identifier);
    parser.writeBits(32, quest.version);
    parser.writeBits(16, quest.size);

    for (0..3) |i| {
        parser.writeBits(768, @as(u768, @bitCast(quest.quests[i])));
    }
}

test "Quest: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var quest = &parser.charsave.quest_data;
    quest.identifier = @intFromEnum(SaveIdentifiers.quest);
    quest.version = 6;
    quest.size = 298;

    quest.quests_temp1 = [_]u16{
        1, 4097, 28,   4169,  0,    4,    4121, 1,    1,    4113,  6145, 4101, 4481, 4101, 4133, 1,
        1, 4097, 4125, 5109,  4097, 4125, 6241, 1,    1,    4097,  4865, 44,   1,    0,    0,    0,
        0, 0,    0,    32802, 4097, 6025, 12,   4153, 5725, 32770, 0,    0,    0,    0,    0,    0,
    };
    quest.quests_temp2 = [_]u16{
        1, 4097, 12,  32841, 0,     0,     4121, 1,    1,    4113,  7289, 4101, 4481, 5, 37, 1,
        1, 1,    133, 1013,  1,     9,     2145, 1,    1,    4097,  4865, 4097, 1,    0, 0,  0,
        1, 0,    0,   32802, 36865, 33162, 0,    4153, 1041, 32770, 0,    0,    0,    0, 0,  0,
    };
    quest.quests_temp3 = [_]u16{
        1, 4097, 4125, 36937, 5145, 4117,  4121, 1,    1,    4113,  7289, 4101,  4481, 4101, 4133, 1,
        1, 4097, 4101, 5109,  4097, 4121,  4193, 1,    1,    4097,  4865, 36865, 1,    0,    0,    0,
        1, 0,    0,    32801, 8,    38793, 12,   4121, 5981, 32770, 0,    0,     0,    0,    0,    0,
    };

    try writeQuest(&parser);

    for (quest_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn writeNPCIntro(parser: *Parser) !void {
    if (parser.out_offset != @intFromEnum(StartOffset.npc_intro) and !is_test) {
        return error.BadStartingOffset;
    }

    const npc = &parser.charsave.npc_data;
    parser.writeBits(16, npc.identifier);
    parser.writeBits(16, npc.size);

    for (0..3) |i| {
        parser.writeBits(64, @as(u64, @bitCast(npc.quest_intro[i])));
    }
    for (0..3) |i| {
        parser.writeBits(64, @as(u64, @bitCast(npc.npc_intro[i])));
    }
}

test "NPC Intro: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var npc = &parser.charsave.npc_data;
    npc.identifier = @intFromEnum(SaveIdentifiers.npc);
    npc.size = 52;
    npc.quest_intro[0].temp = [_]u8{ 174, 174, 165, 201, 6, 0, 0, 0 };
    npc.quest_intro[1].temp = [_]u8{ 172, 36, 164, 137, 6, 0, 0, 0 };
    npc.quest_intro[2].temp = [_]u8{ 174, 174, 164, 201, 6, 0, 0, 0 };

    npc.npc_intro[0].temp = [_]u8{ 192, 127, 231, 25, 0, 0, 0, 0 };
    npc.npc_intro[1].temp = [_]u8{ 254, 255, 231, 25, 0, 0, 0, 0 };
    npc.npc_intro[2].temp = [_]u8{ 128, 248, 225, 24, 0, 0, 0, 0 };

    try writeNPCIntro(&parser);

    for (npc_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}
