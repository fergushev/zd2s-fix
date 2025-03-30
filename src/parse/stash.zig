const main = @import("../main.zig");

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const item_log = std.log.scoped(.Item);

const d2parser = main.d2parser;
const Parser = d2parser.D2SParser;

const charsave = main.charsave;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const readItemList = main.parse_item.readItemList;
const writeItemList = main.parse_item.writeItemList;

pub fn readStashItems(parser: *Parser) !void {
    const stash = &parser.charsave.stash;

    const stash_header: u16 = try parser.readBits(u16, 16);
    if (stash_header == @intFromEnum(SaveIdentifiers.items)) {
        stash.item_list_header.identifier = stash_header;
        stash.item_list_header.item_count = try parser.readBits(u16, 16);
    } else {
        stash.item_list_header.identifier = 0;
        stash.item_list_header.item_count = stash_header;
    }

    if (stash.item_list_header.item_count > 0 or parser.item_details.stash_items > 0) {
        const num_items: usize = @as(usize, @intCast(parser.item_details.stash_items));

        stash.item = try parser.allocator.alloc(charsave.BasicItem, num_items);
        for (stash.item) |*pitem| {
            pitem.* = std.mem.zeroes(charsave.BasicItem);
            pitem.*.item_source = .stash;
            pitem.*.is_socket = false;
            pitem.*.section_end_offset = parser.buffer.len * 8;
        }

        parser.item_details.current_index = 0;
        try readItemList(parser, &stash.item);
    }
}

pub fn writeStashItems(parser: *Parser) !void {
    const stash = &parser.charsave.stash;
    var before_count = parser.out_offset;

    if (stash.item_list_header.identifier == 0) {
        parser.writeBits(16, stash.item_list_header.item_count);
    } else {
        parser.writeBits(16, stash.item_list_header.identifier);
        before_count = parser.out_offset;
        parser.writeBits(16, stash.item_list_header.item_count);
    }

    if (stash.item_list_header.item_count > 0 or parser.item_details.stash_items > 0) {
        const item_count: u16 = try writeItemList(parser, &stash.item);

        const current_offset = parser.out_offset;
        parser.out_offset = before_count;
        stash.item_list_header.item_count = item_count;
        parser.writeBits(16, stash.item_list_header.item_count);
        parser.out_offset = current_offset;
    }

    if (main.log_item) {
        // item_log.debug("REMOVED ITEMS: {d}\n\n", .{parser.item_details.removed_items});
    }
}
