const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const corpse_log = std.log.scoped(.Corpse);

const Parser = main.d2parser.D2SParser;

const charsave = main.charsave;

const States = main.d2txt.States;

const ItemStats = main.isc.ItemStats;
const readItemList = main.parse_item.readItemList;
const writeItemList = main.parse_item.writeItemList;

pub fn readCorpseItems(parser: *Parser) !void {
    parser.charsave.corpse.item_list_header = std.mem.zeroes(@TypeOf(parser.charsave.corpse.item_list_header));

    var corpse = &parser.charsave.corpse;
    corpse.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(corpse.identifier, .items);

    corpse.has_corpse = try parser.readBits(u16, 16);

    if (corpse.has_corpse == 1) {
        corpse.unknown = try parser.readBits(u32, 32);
        corpse.corpseX = try parser.readBits(u32, 32);
        corpse.corpseY = try parser.readBits(u32, 32);

        corpse.item_list_header.identifier = try parser.readBits(u16, 16);
        try verifyIdentifier(corpse.item_list_header.identifier, .items);
        corpse.item_list_header.item_count = try parser.readBits(u16, 16);

        if (corpse.item_list_header.item_count > 0 and parser.item_details.corpse_items != -1) {
            const num_items: usize = @as(usize, @intCast(parser.item_details.corpse_items));

            corpse.item = try parser.allocator.alloc(charsave.BasicItem, num_items);
            for (corpse.item) |*pitem| {
                pitem.* = std.mem.zeroes(charsave.BasicItem);
                pitem.*.item_source = .corpse;
                pitem.*.is_socket = false;
                pitem.*.section_end_offset = parser.item_details.merc_start;
            }

            parser.item_details.current_index = 0;
            try readItemList(parser, &corpse.item);
        }
    }
}

pub fn writeCorpseItems(parser: *Parser) !void {
    const corpse = &parser.charsave.corpse;
    parser.writeBits(16, corpse.identifier);
    const before_has_corpse = parser.out_offset;
    parser.writeBits(16, corpse.has_corpse);

    if (corpse.has_corpse == 1) {
        parser.writeBits(32, corpse.unknown);
        parser.writeBits(32, corpse.corpseX);
        parser.writeBits(32, corpse.corpseY);

        parser.writeBits(16, corpse.item_list_header.identifier);
        const before_count = parser.out_offset;
        parser.writeBits(16, corpse.item_list_header.item_count);

        if (corpse.item_list_header.item_count > 0 and parser.item_details.corpse_items != -1) {
            const item_count: u16 = try writeItemList(parser, &corpse.item);

            const current_offset = parser.out_offset;
            corpse.item_list_header.item_count = item_count;

            if (corpse.item_list_header.item_count == 0) {
                // Zero out the corpse item section if we originally had items but they were all bad
                //  so we dont accidentally break the merc section
                parser.out_offset = before_has_corpse;
                parser.writeBits(128, @as(u8, 0));
                parser.out_offset = before_has_corpse + 16;
            } else {
                parser.out_offset = before_count;
                parser.writeBits(16, corpse.item_list_header.item_count);
                parser.out_offset = current_offset;
            }
        }
    }
}
