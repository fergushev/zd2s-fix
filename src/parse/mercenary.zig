const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const merc_log = std.log.scoped(.Merc);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

const charsave = main.charsave;
const readItemList = main.parse_item.readItemList;
const writeItemList = main.parse_item.writeItemList;

var merc_test_buffer = [_]u8{
    0x00, 0x00, 0x01, 0x00,
    0x9B, 0xF7, 0x79, 0xCF,
    0x0D, 0x00, 0x07, 0x00,
    0x50, 0xA5, 0xAF, 0x05,
};

/// Size: 128
pub fn readMercenary(parser: *Parser) !void {
    parser.charsave.mercenary = std.mem.zeroes(@TypeOf(parser.charsave.mercenary));
    if (parser.offset != @intFromEnum(StartOffset.mercenary) and !is_test) {
        return error.BadStartingOffset;
    }

    var merc = &parser.charsave.mercenary;
    merc.flags = @bitCast(try parser.readBits(u32, 32));
    merc.seed = try parser.readBits(u32, 32);
    merc.name_id = try parser.readBits(u16, 16);
    merc.merc_id = try parser.readBits(u16, 16);
    merc.experience = try parser.readBits(u32, 32);

    if (main.log_mercenary) {
        merc_log.debug("Dead: {any}, Seed: {d}", .{ merc.flags.is_dead, merc.seed });
        merc_log.debug("Name: {d}, Id: {d}, Exp: {d}", .{ merc.name_id, merc.merc_id, merc.experience });
    }
}

test "mercenary: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &merc_test_buffer;

    try readMercenary(&parser);

    try expectEqual(65536, parser.charsave.mercenary.flags);
    try expectEqual(3480876955, parser.charsave.mercenary.seed);
    try expectEqual(13, parser.charsave.mercenary.name_id);
    try expectEqual(7, parser.charsave.mercenary.merc_id);
    try expectEqual(95397200, parser.charsave.mercenary.experience);
}

pub fn writeMercenary(parser: *Parser) !void {
    if (parser.out_offset != @intFromEnum(StartOffset.mercenary) and !is_test) {
        return error.BadStartingOffset;
    }

    const merc = &parser.charsave.mercenary;

    parser.writeBits(32, @as(u32, @bitCast(merc.flags)));
    parser.writeBits(32, merc.seed);
    parser.writeBits(16, merc.name_id);
    parser.writeBits(16, merc.merc_id);
    parser.writeBits(32, merc.experience);
}

test "mercenary: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var merc = &parser.charsave.mercenary;
    merc.flags = 65536;
    merc.seed = 3480876955;
    merc.name_id = 13;
    merc.merc_id = 7;
    merc.experience = 95397200;

    try writeMercenary(&parser);

    for (merc_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn readMercenaryItems(parser: *Parser) !void {
    parser.charsave.merc_items.item_list_header = std.mem.zeroes(@TypeOf(parser.charsave.merc_items.item_list_header));

    const merc = &parser.charsave.mercenary;
    var merc_items = &parser.charsave.merc_items;

    if (!parser.charsave.character_data.save_flags.expansion) {
        return;
    }

    merc_items.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(merc_items.identifier, .merc);

    if (merc.experience == 0 and merc.seed == 0 and merc.name_id == 0) {
        merc_log.debug("No merc found", .{});
        return;
    }

    merc_items.item_list_header.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(merc_items.item_list_header.identifier, .items);

    merc_items.item_list_header.item_count = try parser.readBits(u16, 16);

    if (main.log_mercenary) {
        merc_log.debug("Item Count: {d}", .{merc_items.item_list_header.item_count});
    }

    if (merc_items.item_list_header.item_count > 0 and parser.item_details.merc_items != -1) {
        const num_items: usize = @as(usize, @intCast(parser.item_details.merc_items));

        merc_items.item = try parser.allocator.alloc(charsave.BasicItem, num_items);
        for (merc_items.item) |*pitem| {
            pitem.* = std.mem.zeroes(charsave.BasicItem);
            pitem.*.item_source = .mercenary;
            pitem.*.is_socket = false;
            pitem.*.section_end_offset = parser.item_details.golem_start;
        }

        parser.item_details.current_index = 0;
        try readItemList(parser, &merc_items.item);
    }
}

pub fn writeMercenaryItems(parser: *Parser) !void {
    const merc = &parser.charsave.mercenary;
    const merc_items = &parser.charsave.merc_items;
    parser.writeBits(16, merc_items.identifier);

    if (merc.experience == 0 and merc.seed == 0 and merc.name_id == 0) {
        return;
    }

    parser.writeBits(16, merc_items.item_list_header.identifier);
    const before_count = parser.out_offset;
    parser.writeBits(16, merc_items.item_list_header.item_count);

    if (merc_items.item_list_header.item_count > 0 and parser.item_details.merc_items != -1) {
        const item_count: u16 = try writeItemList(parser, &merc_items.item);

        const current_offset = parser.out_offset;
        parser.out_offset = before_count;
        merc_items.item_list_header.item_count = item_count;
        parser.writeBits(16, merc_items.item_list_header.item_count);
        parser.out_offset = current_offset;
    }
}
