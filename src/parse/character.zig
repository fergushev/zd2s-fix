const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;
const BasicItem = main.charsave.BasicItem;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const character_log = std.log.scoped(.Character);
const equip_log = std.log.scoped(.Equipment);
const stats_log = std.log.scoped(.Stats);
const skills_log = std.log.scoped(.Skills);
const item_log = std.log.scoped(.Item);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

const ItemStats = main.isc.ItemStats;
const max_item_stat = main.isc.max_item_stat;

const readItemList = main.parse_item.readItemList;
const writeItemList = main.parse_item.writeItemList;

var character_test_buffer = [_]u8{
    0x00, 0x00, 0x00, 0x00, 0x61, 0x79, 0x6C, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x68, 0x0F, 0x00, 0x00, 0x00, 0x10, 0x21, 0x63, 0x00, 0x00, 0x00, 0x00,
    0xF9, 0xF1, 0x0D, 0x67, 0xFF, 0xFF, 0xFF, 0xFF,
};
var equipment_test_buffer = [_]u8{
    0xFF, 0x03, 0x02, 0x02, 0x02, 0x21, 0xFF, 0xFF, 0x02, 0x02, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0x48, 0x48, 0x48, 0x48, 0xAF, 0xFF, 0xFF, 0x48, 0x48, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
};
var stats_test_buffer = [_]u8{
    0x67, 0x66, 0x00, 0x3C, 0x09, 0xF0, 0x80, 0x80, 0x49, 0x06, 0xD4, 0x43, 0x80, 0x82, 0x02, 0x02,
    0x06, 0x00, 0x4A, 0xCC, 0x01, 0x80, 0xEA, 0x81, 0x00, 0x20, 0x24, 0x24, 0x00, 0x98, 0x06, 0x0A,
    0x00, 0x1E, 0xC6, 0x02, 0x80, 0xFD, 0xC0, 0x60, 0xDC, 0xC0, 0xF0, 0xCA, 0x3A, 0xFA, 0x81, 0xC1,
    0xDB, 0x96, 0xFF,
};
var skills_test_buffer = [_]u8{
    0x69, 0x66, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00,
    0x00, 0x01, 0x14, 0x01, 0x00, 0x01, 0x00, 0x0F,
    0x14, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00,
    0x01, 0x01, 0x00, 0x00, 0x14, 0x01, 0x14, 0x01,
    0x00, 0x00, 0x00,
};

/// Size: 320
pub fn readCharacterData(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.char_data) and !is_test) {
        return error.BadStartingOffset;
    }

    parser.charsave.character_data = std.mem.zeroes(@TypeOf(parser.charsave.character_data));
    var chardata = &parser.charsave.character_data;

    chardata.weapon_swap = try parser.readBits(u32, 32);
    try parser.readByteArray(&chardata.name);
    chardata.save_flags = @bitCast(try parser.readBits(u32, 32));

    chardata.class = @enumFromInt(try parser.readBits(u8, 8));
    chardata.stats = try parser.readBits(u8, 8);
    chardata.skills = try parser.readBits(u8, 8);
    chardata.level = try parser.readBits(u8, 8);

    chardata.create_time = try parser.readBits(u32, 32);
    chardata.last_played = try parser.readBits(u32, 32);
    chardata.play_time = try parser.readBits(u32, 32);

    if (main.log_character) {
        character_log.debug("Name: {s}, Class: {s}, Weap Swap: {x}", .{ chardata.name, @tagName(chardata.class), chardata.weapon_swap });
        character_log.debug("Flags: {any}", .{chardata.save_flags});
        character_log.debug("Stats: {d}, Skills: {d}, Level: {d}", .{ chardata.stats, chardata.skills, chardata.level });
        character_log.debug("Create Time: {d}, Last Played: {d}, Play Time: 0x{x}", .{ chardata.create_time, chardata.last_played, chardata.play_time });
    }
}

test "character: read character good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &character_test_buffer;

    try readCharacterData(&parser);

    const name = [_]u8{
        'a', 'y', 'l', 'a',
        0,   0,   0,   0,
        0,   0,   0,   0,
        0,   0,   0,   0,
    };

    try expectEqual(0, parser.charsave.character_data.weapon_swap);
    try expectEqualStrings(&name, &parser.charsave.character_data.name);

    const save_flags: u32 = @bitCast(parser.charsave.character_data.save_flags);
    try expectEqual(3944, save_flags);
    try expectEqual(0, parser.charsave.character_data.class);
    try expectEqual(16, parser.charsave.character_data.stats);
    try expectEqual(33, parser.charsave.character_data.skills);
    try expectEqual(99, parser.charsave.character_data.level);

    try expectEqual(0, parser.charsave.character_data.create_time);
    try expectEqual(1728967161, parser.charsave.character_data.last_played);
    try expectEqual(0xffffffff, parser.charsave.character_data.play_time);
}

pub fn writeCharacterData(parser: *Parser) void {
    const chardata = &parser.charsave.character_data;
    parser.writeBits(32, chardata.weapon_swap);
    parser.writeByteArray(&chardata.name);
    parser.writeBits(32, @as(u32, @bitCast(chardata.save_flags)));
    parser.writeBits(8, @intFromEnum(chardata.class));
    parser.writeBits(8, chardata.stats);
    parser.writeBits(8, chardata.skills);
    parser.writeBits(8, chardata.level);

    parser.writeBits(32, chardata.create_time);
    parser.writeBits(32, chardata.last_played);
    parser.writeBits(32, chardata.play_time);
}

test "character: write character good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var chardata = &parser.charsave.character_data;

    chardata.weapon_swap = 0;
    chardata.name = [_]u8{
        'a', 'y', 'l', 'a',
        0,   0,   0,   0,
        0,   0,   0,   0,
        0,   0,   0,   0,
    };

    chardata.save_flags = @bitCast(@as(u32, 3944));
    chardata.class = 0;
    chardata.stats = 16;
    chardata.skills = 33;
    chardata.level = 99;

    chardata.create_time = 0;
    chardata.last_played = 1728967161;
    chardata.play_time = 0xffffffff;

    writeCharacterData(&parser);

    for (character_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

/// Size: 256
pub fn readEquipment(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.equipment) and !is_test) {
        return error.BadStartingOffset;
    }

    const component = &parser.charsave.equipment.component;
    const color = &parser.charsave.equipment.color;

    component.head = try parser.readBits(u8, 8);
    component.torso = try parser.readBits(u8, 8);
    component.legs = try parser.readBits(u8, 8);
    component.right_arm = try parser.readBits(u8, 8);
    component.left_arm = try parser.readBits(u8, 8);
    component.right_hand = try parser.readBits(u8, 8);
    component.left_hand = try parser.readBits(u8, 8);
    component.shield = try parser.readBits(u8, 8);

    component.special_1 = try parser.readBits(u8, 8);
    component.special_2 = try parser.readBits(u8, 8);
    component.special_3 = try parser.readBits(u8, 8);
    component.special_4 = try parser.readBits(u8, 8);
    component.special_5 = try parser.readBits(u8, 8);
    component.special_6 = try parser.readBits(u8, 8);
    component.special_7 = try parser.readBits(u8, 8);
    component.special_8 = try parser.readBits(u8, 8);

    color.head = try parser.readBits(u8, 8);
    color.torso = try parser.readBits(u8, 8);
    color.legs = try parser.readBits(u8, 8);
    color.right_arm = try parser.readBits(u8, 8);
    color.left_arm = try parser.readBits(u8, 8);
    color.right_hand = try parser.readBits(u8, 8);
    color.left_hand = try parser.readBits(u8, 8);
    color.shield = try parser.readBits(u8, 8);

    color.special_1 = try parser.readBits(u8, 8);
    color.special_2 = try parser.readBits(u8, 8);
    color.special_3 = try parser.readBits(u8, 8);
    color.special_4 = try parser.readBits(u8, 8);
    color.special_5 = try parser.readBits(u8, 8);
    color.special_6 = try parser.readBits(u8, 8);
    color.special_7 = try parser.readBits(u8, 8);
    color.special_8 = try parser.readBits(u8, 8);

    if (main.log_character) {
        equip_log.debug("Component: {any}", .{component});
        equip_log.debug("Color: {any}", .{component});
    }
}

test "character: read equip good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &equipment_test_buffer;

    const component = &parser.charsave.equipment.component;
    const color = &parser.charsave.equipment.color;

    try readEquipment(&parser);

    try expectEqual(255, component.head);
    try expectEqual(3, component.torso);
    try expectEqual(2, component.legs);
    try expectEqual(2, component.right_arm);
    try expectEqual(2, component.left_arm);
    try expectEqual(33, component.right_hand);
    try expectEqual(255, component.left_hand);
    try expectEqual(255, component.shield);

    try expectEqual(2, component.special_1);
    try expectEqual(2, component.special_2);
    try expectEqual(255, component.special_3);
    try expectEqual(255, component.special_4);
    try expectEqual(255, component.special_5);
    try expectEqual(255, component.special_6);
    try expectEqual(255, component.special_7);
    try expectEqual(255, component.special_8);

    try expectEqual(255, color.head);
    try expectEqual(72, color.torso);
    try expectEqual(72, color.legs);
    try expectEqual(72, color.right_arm);
    try expectEqual(72, color.left_arm);
    try expectEqual(175, color.right_hand);
    try expectEqual(255, color.left_hand);
    try expectEqual(255, color.shield);

    try expectEqual(72, color.special_1);
    try expectEqual(72, color.special_2);
    try expectEqual(255, color.special_3);
    try expectEqual(255, color.special_4);
    try expectEqual(255, color.special_5);
    try expectEqual(255, color.special_6);
    try expectEqual(255, color.special_7);
    try expectEqual(255, color.special_8);
}

pub fn writeEquipment(parser: *Parser) void {
    const component = &parser.charsave.equipment.component;
    const color = &parser.charsave.equipment.color;

    parser.writeBits(8, component.head);
    parser.writeBits(8, component.torso);
    parser.writeBits(8, component.legs);
    parser.writeBits(8, component.right_arm);
    parser.writeBits(8, component.left_arm);
    parser.writeBits(8, component.right_hand);
    parser.writeBits(8, component.left_hand);
    parser.writeBits(8, component.shield);

    parser.writeBits(8, component.special_1);
    parser.writeBits(8, component.special_2);
    parser.writeBits(8, component.special_3);
    parser.writeBits(8, component.special_4);
    parser.writeBits(8, component.special_5);
    parser.writeBits(8, component.special_6);
    parser.writeBits(8, component.special_7);
    parser.writeBits(8, component.special_8);

    parser.writeBits(8, color.head);
    parser.writeBits(8, color.torso);
    parser.writeBits(8, color.legs);
    parser.writeBits(8, color.right_arm);
    parser.writeBits(8, color.left_arm);
    parser.writeBits(8, color.right_hand);
    parser.writeBits(8, color.left_hand);
    parser.writeBits(8, color.shield);

    parser.writeBits(8, color.special_1);
    parser.writeBits(8, color.special_2);
    parser.writeBits(8, color.special_3);
    parser.writeBits(8, color.special_4);
    parser.writeBits(8, color.special_5);
    parser.writeBits(8, color.special_6);
    parser.writeBits(8, color.special_7);
    parser.writeBits(8, color.special_8);
}

test "character: write equip good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    const component = &parser.charsave.equipment.component;
    const color = &parser.charsave.equipment.color;

    component.head = 255;
    component.torso = 3;
    component.legs = 2;
    component.right_arm = 2;
    component.left_arm = 2;
    component.right_hand = 33;
    component.left_hand = 255;
    component.shield = 255;

    component.special_1 = 2;
    component.special_2 = 2;
    component.special_3 = 255;
    component.special_4 = 255;
    component.special_5 = 255;
    component.special_6 = 255;
    component.special_7 = 255;
    component.special_8 = 255;

    color.head = 255;
    color.torso = 72;
    color.legs = 72;
    color.right_arm = 72;
    color.left_arm = 72;
    color.right_hand = 175;
    color.left_hand = 255;
    color.shield = 255;

    color.special_1 = 72;
    color.special_2 = 72;
    color.special_3 = 255;
    color.special_4 = 255;
    color.special_5 = 255;
    color.special_6 = 255;
    color.special_7 = 255;
    color.special_8 = 255;

    writeEquipment(&parser);

    for (equipment_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn readCharacterStats(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.char_stats) and !is_test) {
        return error.BadStartingOffset;
    }
    var charstats = &parser.charsave.stats;
    charstats.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(charstats.identifier, .stats);

    var csv_bits: u32 = 0;
    var stat_id: u32 = try parser.readBits(u32, 9);

    while (stat_id != max_item_stat) {
        csv_bits = parser.isc_list.items[stat_id].csv_bits;
        if (csv_bits == 0) {
            return error.InvalidCsvBits;
        }

        try charstats.char_statlist.put(stat_id, try parser.readBits(u32, csv_bits));

        stat_id = try parser.readBits(u16, 9);
    }

    parser.alignToByte();

    if (main.log_character) {
        var it = charstats.char_statlist.iterator();
        while (it.next()) |statlist| {
            stats_log.debug("{s}: {d}", .{
                @tagName(@as(ItemStats, @enumFromInt(statlist.key_ptr.*))),
                statlist.value_ptr.*,
            });
        }
    }
}

test "character: read stats good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var charstats = &parser.charsave.stats;
    parser.buffer = &stats_test_buffer;

    try readCharacterStats(&parser);

    try expectEqual(@intFromEnum(SaveIdentifiers.stats), parser.charsave.stats.identifier);

    var it = charstats.char_statlist.iterator();
    while (it.next()) |statlist| {
        const stat_id = statlist.key_ptr.*;
        const stat_value = statlist.value_ptr.*;

        switch (@as(ItemStats, @enumFromInt(stat_id))) {
            .strength => {
                try expectEqual(158, stat_value);
            },
            .energy => {
                try expectEqual(15, stat_value);
            },
            .dexterity => {
                try expectEqual(147, stat_value);
            },
            .vitality => {
                try expectEqual(245, stat_value);
            },
            .statpts => {
                try expectEqual(20, stat_value);
            },
            .newskills => {
                try expectEqual(2, stat_value);
            },
            .hitpoints => {
                try expectEqual(402688, stat_value);
            },
            .maxhp => {
                try expectEqual(251136, stat_value);
            },
            .mana => {
                try expectEqual(73984, stat_value);
            },
            .maxmana => {
                try expectEqual(54016, stat_value);
            },
            .stamina => {
                try expectEqual(200448, stat_value);
            },
            .maxstamina => {
                try expectEqual(129792, stat_value);
            },
            .level => {
                try expectEqual(99, stat_value);
            },
            .experience => {
                try expectEqual(3520485254, stat_value);
            },
            .gold => {
                try expectEqual(0, stat_value);
            },
            .goldbank => {
                try expectEqual(5992198, stat_value);
            },
            else => {
                continue;
            },
        }
    }
}

pub fn writeCharacterStats(parser: *Parser) void {
    const charstats = &parser.charsave.stats;
    parser.writeBits(16, charstats.identifier);

    var it = charstats.char_statlist.iterator();
    while (it.next()) |statlist| {
        if (statlist.value_ptr.* > 0) {
            const stat_id: u9 = @intCast(statlist.key_ptr.*);
            const csv_bits = parser.isc_list.items[stat_id].csv_bits;

            parser.writeBits(9, stat_id);
            parser.writeBits(csv_bits, statlist.value_ptr.*);
        }
    }

    parser.writeBits(9, @as(u9, max_item_stat));

    parser.padToByte();
}

test "character: write stats good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var charstats = &parser.charsave.stats;

    charstats.identifier = @intFromEnum(SaveIdentifiers.stats);

    try charstats.char_statlist.put(@intFromEnum(ItemStats.strength), 158);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.energy), 15);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.dexterity), 147);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.vitality), 245);

    try charstats.char_statlist.put(@intFromEnum(ItemStats.statpts), 20);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.newskills), 2);

    try charstats.char_statlist.put(@intFromEnum(ItemStats.hitpoints), 402688);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.maxhp), 251136);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.mana), 73984);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.maxmana), 54016);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.stamina), 200448);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.maxstamina), 129792);

    try charstats.char_statlist.put(@intFromEnum(ItemStats.level), 99);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.experience), 3520485254);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.gold), 0);
    try charstats.char_statlist.put(@intFromEnum(ItemStats.goldbank), 5992198);

    writeCharacterStats(&parser);

    for (stats_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn readCharacterSkills(parser: *Parser) !void {
    parser.charsave.skills = std.mem.zeroes(@TypeOf(parser.charsave.skills));
    var charskills = &parser.charsave.skills;
    charskills.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(charskills.identifier, .skills);
    try parser.readByteArray(&charskills.skills);

    if (main.log_character) {
        skills_log.debug("Skills: {any}", .{charskills.skills});
    }
}

test "character: read skills good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &skills_test_buffer;

    try readCharacterSkills(&parser);

    const skills = [_]u8{
        0, 0, 1,  1,  1,  0, 0,  1, 20, 1, 0,
        1, 0, 15, 20, 0,  0, 1,  1, 1,  0, 0,
        1, 1, 0,  0,  20, 1, 20, 1, 0,  0, 0,
    };

    try expectEqual(@intFromEnum(SaveIdentifiers.skills), parser.charsave.skills.identifier);
    try expectEqual(skills, parser.charsave.skills.skills);
}

pub fn writeCharacterSkills(parser: *Parser) void {
    const charskills = &parser.charsave.skills;
    parser.writeBits(16, charskills.identifier);
    parser.writeByteArray(&charskills.skills);
}

test "character: write skills good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var charskills = &parser.charsave.skills;
    charskills.identifier = @intFromEnum(SaveIdentifiers.skills);
    charskills.skills = [_]u8{
        0, 0, 1,  1,  1,  0, 0,  1, 20, 1, 0,
        1, 0, 15, 20, 0,  0, 1,  1, 1,  0, 0,
        1, 1, 0,  0,  20, 1, 20, 1, 0,  0, 0,
    };

    writeCharacterSkills(&parser);

    for (skills_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn readCharacterItems(parser: *Parser) !void {
    parser.charsave.items.item_list_header = std.mem.zeroes(@TypeOf(parser.charsave.items.item_list_header));

    var charitem = &parser.charsave.items;
    charitem.item_list_header.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(charitem.item_list_header.identifier, .items);

    charitem.item_list_header.item_count = try parser.readBits(u16, 16);

    if (charitem.item_list_header.item_count > 0 and parser.item_details.player_items != -1) {
        const num_items: usize = @as(usize, @intCast(parser.item_details.player_items));

        charitem.item = try parser.allocator.alloc(BasicItem, num_items);
        for (charitem.item) |*pitem| {
            pitem.* = std.mem.zeroes(BasicItem);
            pitem.*.item_source = .player;
            pitem.*.is_socket = false;
            pitem.*.section_end_offset = parser.item_details.corpse_start;
        }

        parser.item_details.current_index = 0;
        try readItemList(parser, &charitem.item);
    }
}

pub fn writeCharacterItems(parser: *Parser) !void {
    const charitem = &parser.charsave.items;
    parser.writeBits(16, charitem.item_list_header.identifier);
    const before_count = parser.out_offset;
    parser.writeBits(16, charitem.item_list_header.item_count);

    if (charitem.item_list_header.item_count > 0 and parser.item_details.player_items != -1) {
        const item_count: u16 = try writeItemList(parser, &charitem.item);

        const current_offset = parser.out_offset;
        parser.out_offset = before_count;
        charitem.item_list_header.item_count = item_count;
        parser.writeBits(16, charitem.item_list_header.item_count);
        parser.out_offset = current_offset;
    }
}
