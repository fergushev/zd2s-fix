const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const SaveIdentifiers = main.charsave.SaveIdentifiers;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const golem_log = std.log.scoped(.Golem);
const item_log = std.log.scoped(.Item);

const Parser = main.d2parser.D2SParser;

const charsave = main.charsave;
const readItemList = main.parse_item.readItemList;
const writeItemList = main.parse_item.writeItemList;

pub fn readGolemItems(parser: *Parser) !void {
    parser.charsave.golem = std.mem.zeroes(@TypeOf(parser.charsave.golem));

    var golem = &parser.charsave.golem;
    golem.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(golem.identifier, .golem);

    const has_golem: u8 = try parser.readBits(u8, 8);
    if (has_golem != 0 and has_golem != 1) {
        return error.BadIronGolem;
    }
    golem.has_golem = @as(u1, @intCast(has_golem));
    if (main.log_golem) {
        golem_log.debug("HAS GOLEM: {any}", .{golem.has_golem});
    }

    if (golem.has_golem == 1) {
        golem.item = try parser.allocator.alloc(charsave.BasicItem, 1);
        for (golem.item) |*pitem| {
            pitem.* = std.mem.zeroes(charsave.BasicItem);
            pitem.*.item_source = .golem;
            pitem.*.is_socket = false;
            pitem.*.section_end_offset = parser.buffer.len * 8;
        }

        parser.item_details.current_index = 0;
        try readItemList(parser, &golem.item);
    }
}

pub fn writeGolemItems(parser: *Parser) !void {
    const golem = &parser.charsave.golem;
    parser.writeBits(16, golem.identifier);
    parser.writeBits(8, golem.has_golem);

    if (golem.has_golem == 1) {
        _ = try writeItemList(parser, &golem.item);
    }

    if (main.log_item) {
        // item_log.err("REMOVED ITEMS: {d}\n\n", .{parser.item_details.removed_items});
    }
}
