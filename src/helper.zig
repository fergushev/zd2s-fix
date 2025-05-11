const main = @import("main.zig");

const std = @import("std");
const Dir = std.fs.Dir;
const print = std.debug.print;
const helper_log = std.log.scoped(.Helper);

const SaveIdentifiers = main.charsave.SaveIdentifiers;
const ItemQualities = main.charsave.ItemQualities;
const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;
const ItemOffsetDetails = main.d2parser.ItemOffsetDetails;
const charsave = main.charsave;
const ItemFlags = main.charsave.ItemFlags;

pub fn loadCharSave(allocator: std.mem.Allocator, dir: Dir, save_path: []const u8) ![]u8 {
    const char_file = try dir.openFile(save_path, .{});
    defer char_file.close();

    const stat = try char_file.stat();
    const buffer = try char_file.readToEndAlloc(allocator, stat.size);

    return buffer;
}

pub fn csvLineCount(allocator: std.mem.Allocator, file_name: []const u8) !usize {
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(buffer);

    const exp_count = std.mem.count(u8, buffer, "Expansion\t\t");
    var count = std.mem.count(u8, buffer, "\n") - 1;
    count -= exp_count;

    return count;
}

pub fn findAllEquivalentTypes(itype: []u8, all_types: *std.StringHashMap(bool), equiv1_map: *std.StringHashMap([]u8), equiv2_map: *std.StringHashMap([]u8)) !void {
    try all_types.put(itype, true);

    if (equiv1_map.contains(itype)) {
        try findAllEquivalentTypes(equiv1_map.get(itype).?, all_types, equiv1_map, equiv2_map);
    }

    if (equiv2_map.contains(itype)) {
        try findAllEquivalentTypes(equiv2_map.get(itype).?, all_types, equiv1_map, equiv2_map);
    }
}

pub fn verifyIdentifier(actual: anytype, expected: SaveIdentifiers) !void {
    if (actual != @intFromEnum(expected)) {
        helper_log.debug("Invalid Identifier: 0x{x}", .{actual});
        return error.InvalidIdentifier;
    }
}

pub fn verifyItemQuality(quality: u8) !ItemQualities {
    if (quality > 0 and quality < 10) {
        return @enumFromInt(quality);
    } else {
        return error.InvalidItemQuality;
    }
}

pub fn calcChecksum(buffer: []u8, size: u32) !u32 {
    if (buffer.len == 0) {
        return error.EmptySaveBuffer;
    } else if (size == 0) {
        return error.EmptySaveSize;
    }

    std.mem.writeVarPackedInt(buffer, 96, 32, @as(u32, 0), .little);

    var checksum: i32 = 0;
    for (0..size) |i| {
        const byte: i32 = buffer[i];
        checksum = byte +% @intFromBool(checksum < 0) +% checksum *% 2;
    }

    return @as(u32, @bitCast(checksum));
}

/// Compact Items _have_ to be at least 13 bytes in order to be valid
/// and extended items have to be at least 21 bytes.
/// If we find one that's smaller, it's just a JM word that _happened_ to be inside of a "valid" item.
fn getMinItemSize(parser: *Parser) !usize {
    const before_offset: usize = parser.offset;

    var min_bits: usize = 0;
    const flags: ItemFlags = @bitCast(try parser.readBits(u32, 32));
    parser.offset = before_offset;

    if (flags.compact) {
        min_bits = 104;
    } else {
        min_bits = 168;
    }
    return min_bits;
}

/// Assumes an expansion character file is in the buffer. Classic is more than likely broken here
/// This isn't pretty, you've been warned
pub fn getItemDetails(parser: *Parser) !void {
    const start_offset: usize = parser.offset;

    const details = parser.item_details;

    var cur_byte: u8 = 0;
    var prev_byte: u8 = 0;
    var last_offset: usize = 0;

    var found_player: bool = false;
    var found_corpse: bool = false;
    var found_merc: bool = false;

    const file_bitsize = parser.charsave.header.size * 8;
    const merc = &parser.charsave.mercenary;

    // First pass: get all section starting offsets
    while (parser.offset < file_bitsize) {
        prev_byte = cur_byte;
        cur_byte = try parser.readBits(u8, 8);

        if (!found_corpse and cur_byte == 0x4D and prev_byte == 0x4A) {
            if (parser.offset - last_offset == 48) {
                if (!found_player) {
                    found_player = true;
                    details.player_start = last_offset;
                } else if (!found_corpse) {
                    found_corpse = true;
                    details.corpse_start = last_offset - 128;
                }
            }
            last_offset = parser.offset - 16;
        } else if (!found_merc and cur_byte == 0x66 and prev_byte == 0x6A) {
            const merc_first: u8 = try parser.readBits(u8, 8);
            const merc_sec: u8 = try parser.readBits(u8, 8);

            if (merc_first == 0x6B and merc_sec == 0x66) {
                found_merc = true;
                details.merc_start = parser.offset - 32;
                details.golem_start = parser.offset - 16;
                if (!found_corpse) {
                    details.corpse_start = last_offset;
                }
                break;
            } else if (merc_first == 0x4A and merc_sec == 0x4D) {
                found_merc = true;
                details.merc_start = parser.offset - 32;
                if (!found_corpse) {
                    details.corpse_start = last_offset;
                }
                if (try parser.readBits(u16, 16) == 0) {
                    details.golem_start = parser.offset;
                    break;
                }
            }
        } else if (found_merc and cur_byte == 0x66 and prev_byte == 0x6B) {
            const has_golem = try parser.readBits(u8, 8);
            if (has_golem == 0 or has_golem == 1) {
                // Not gonna be a JM item id if we're at the end of the file
                if (parser.offset == parser.buffer.len * 8) {
                    parser.offset -= 8;
                    details.golem_start = parser.offset - 16;
                    break;
                }

                const golem_identifier: u16 = try parser.readBits(u16, 16);
                parser.offset -= 24;
                if (golem_identifier == @intFromEnum(SaveIdentifiers.items) or
                    golem_identifier == 0x6470)
                {
                    details.golem_start = parser.offset - 16;
                    break;
                }
            } else {
                parser.offset -= 8;
            }
        }
    }

    if (!found_merc and !found_corpse) {
        details.corpse_start = last_offset;
        details.merc_start = parser.offset;
        details.golem_start = parser.offset;
    }
    parser.offset = details.player_start + 16;

    var has_corpse: bool = false;
    if (details.merc_start - details.corpse_start > 32) {
        has_corpse = true;
    }

    cur_byte = 0;
    prev_byte = 0;
    last_offset = 0;

    var p_index: u16 = 0;
    var c_index: u16 = 0;
    var m_index: u16 = 0;
    var g_index: u16 = 0;

    var has_pd: bool = false;
    var pd_offset: usize = 0;
    var too_small_items: usize = 0;
    var cur_min_length: usize = 0;

    // print("corpse start: {x}\n", .{details.corpse_start / 8});
    // print("merc start: {x}\n", .{details.merc_start / 8});
    // print("golem start: {x}\n", .{details.golem_start / 8});

    // Second pass: get item counts and offsets
    while (parser.offset < file_bitsize) {
        prev_byte = cur_byte;
        cur_byte = try parser.readBits(u8, 8);

        if (cur_byte == 0x4D and prev_byte == 0x4A) {
            if (parser.offset - 16 == details.corpse_start or
                (parser.offset - 144 == details.corpse_start and has_corpse) or
                parser.offset - 32 == details.merc_start)
            {
                continue;
            }

            const item_flags: ItemFlags = @bitCast(try parser.readBits(u32, 32));
            parser.offset -= 32;
            if (item_flags._unused != 0 or
                item_flags.deleted or
                (item_flags.runeword and !item_flags.socketed) or
                (item_flags.ear and (item_flags.ethereal or item_flags.runeword or item_flags.inferior or item_flags.quantity or item_flags.broken or item_flags.repaired)) or
                (item_flags.named and !item_flags.ear) or
                (item_flags.compact and (item_flags.ethereal or item_flags.runeword or item_flags.starter)) or
                (item_flags.starter and (item_flags.ethereal or item_flags.ear or item_flags.runeword or item_flags.quantity or item_flags.init or item_flags.new_item)) or
                (item_flags.broken and item_flags.repaired) or
                (item_flags.switch_in and item_flags.switch_out))
            {
                // Found a JM header that isn't actually the start of an item
                too_small_items += 1;
                // print("TOO SMALL (flags): {x} | \n{any}\n", .{ (parser.offset - 16) / 8, item_flags });
                continue;
            }

            // May not be necessary, above should probably already handle this
            if (parser.offset - last_offset < cur_min_length) {
                too_small_items += 1;
                // print("TOO SMALL: {x}\n", .{(parser.offset - 16) / 8});
                continue;
            }

            cur_min_length = try getMinItemSize(parser);

            if (parser.offset < details.corpse_start) {
                details.player_items += 1;
                try details.player_size.append(.{
                    .start_offset = parser.offset - 16,
                    .length = 0,
                    .end_offset = 0,
                });

                if (details.player_items > 1) {
                    details.player_size.items[p_index - 1].length = parser.offset - 16 - last_offset;
                }
                p_index += 1;
            } else if (parser.offset < details.merc_start) {
                if (!found_corpse or parser.offset - 16 == details.corpse_start + 128) {
                    continue;
                }

                details.corpse_items += 1;
                try details.corpse_size.append(.{
                    .start_offset = parser.offset - 16,
                    .length = 0,
                    .end_offset = 0,
                });

                if (details.corpse_items > 1) {
                    details.corpse_size.items[c_index - 1].length = parser.offset - 16 - last_offset;
                }
                c_index += 1;
            } else if (parser.offset < details.golem_start) {
                if (merc.experience == 0 and merc.seed == 0) {
                    continue;
                }

                details.merc_items += 1;
                try details.merc_size.append(.{
                    .start_offset = parser.offset - 16,
                    .length = 0,
                    .end_offset = 0,
                });

                if (details.merc_items > 1) {
                    details.merc_size.items[m_index - 1].length = parser.offset - 16 - last_offset;
                }
                m_index += 1;
            } else {
                details.golem_items += 1;
                try details.golem_size.append(.{
                    .start_offset = parser.offset - 16,
                    .length = 0,
                    .end_offset = 0,
                });

                if (details.golem_items > 1) {
                    details.golem_size.items[g_index - 1].length = parser.offset - 16 - last_offset;
                }
                g_index += 1;
            }

            last_offset = parser.offset - 16;
        } else if (cur_byte == 0x64 and prev_byte == 0x70 and parser.offset > details.golem_start) { // 'pd'
            has_pd = true;
            pd_offset = parser.offset - 16;
            break;
        }
    }

    var total_length: usize = 0;
    if (details.player_items != 0) {
        details.player_size.items[p_index - 1].length = details.corpse_start - details.player_size.items[p_index - 1].start_offset;
    }

    if (details.corpse_items != 0) {
        details.corpse_size.items[c_index - 1].length = details.merc_start - details.corpse_size.items[c_index - 1].start_offset;
    }

    if (details.merc_items != 0) {
        details.merc_size.items[m_index - 1].length = details.golem_start - details.merc_size.items[m_index - 1].start_offset;
    }

    if (details.golem_items != 0) {
        const golem_fin: usize = if (has_pd) pd_offset else (parser.buffer.len * 8);
        details.golem_size.items[g_index - 1].length = golem_fin - details.golem_size.items[g_index - 1].start_offset;
    }

    for (details.player_size.items) |*item| {
        total_length += item.length;
        item.end_offset = item.start_offset + item.length;
    }
    for (details.corpse_size.items) |*item| {
        total_length += item.length;
        item.end_offset = item.start_offset + item.length;
    }
    for (details.merc_size.items) |*item| {
        total_length += item.length;
        item.end_offset = item.start_offset + item.length;
    }
    for (details.golem_size.items) |*item| {
        total_length += item.length;
        item.end_offset = item.start_offset + item.length;
    }

    const p_count: i16 = details.player_items + 1;
    const c_count: i16 = if (found_corpse) details.corpse_items + 2 else 1;
    const m_count: i16 = if (merc.experience == 0 and merc.seed == 0) 0 else details.merc_items + 1;
    const g_count: i16 = details.golem_items;
    const total_items = p_count + c_count + m_count + g_count;
    // print(
    //     "p_count: {d} | c_count: {d} | m_count: {d} | g_count: {d}, has_pd: {any}\n",
    //     .{ p_count, c_count, m_count, g_count, has_pd },
    // );

    // Only look at the "item" sections, just in case there's a "JM" hiding somewhere else in the file
    const end_offset: usize = if (has_pd) pd_offset else (parser.buffer.len * 8);
    const sliced_buf = parser.buffer[start_offset / 8 .. end_offset / 8];
    var item_count = std.mem.count(u8, sliced_buf, "JM");
    item_count -= too_small_items;
    if (item_count != total_items) {
        // print(
        //     "COUNT: {d} | TOTAL: {d} | SMALL: {d}\n",
        //     .{ item_count, total_items, too_small_items },
        // );
        return error.MissingItems;
    }

    helper_log.debug(
        "Corpse Items: {d}, Merc Items: {d}",
        .{ details.corpse_items, details.merc_items },
    );
    helper_log.debug(
        "Corpse Offset: 0x{x}, Merc Offset: 0x{x}, Golem Offset: 0x{x}",
        .{ details.corpse_start / 8, details.merc_start / 8, details.golem_start / 8 },
    );

    parser.offset = start_offset;
}

pub fn getStashItemDetails(parser: *Parser) !void {
    var cur_byte: u8 = 0;
    var prev_byte: u8 = 0;
    var last_offset: usize = 0;
    const file_bitsize = parser.buffer.len * 8;
    const details = parser.item_details;

    var too_small_items: usize = 0;
    var cur_min_length: usize = 0;
    var index: u16 = 0;
    while (parser.offset < file_bitsize) {
        prev_byte = cur_byte;
        cur_byte = try parser.readBits(u8, 8);

        if (cur_byte == 0x4D and prev_byte == 0x4A) {
            if (parser.offset == 16) {
                // Ignore the header
                continue;
            }
            if (parser.offset - last_offset < cur_min_length) {
                too_small_items += 1;
                continue;
            }

            cur_min_length = try getMinItemSize(parser);

            details.stash_items += 1;
            try details.stash_size.append(.{
                .start_offset = parser.offset - 16,
                .length = 0,
                .end_offset = 0,
            });

            if (last_offset != 0) {
                details.stash_size.items[index - 1].length = parser.offset - 16 - last_offset;
            }
            last_offset = parser.offset - 16;
            index += 1;
        }
    }
    details.stash_size.items[index - 1].length = parser.offset - last_offset;

    var total_length: usize = 0;
    for (details.stash_size.items) |*item| {
        total_length += item.length;
        item.end_offset = item.start_offset + item.length;
    }

    var item_count = std.mem.count(u8, parser.buffer, "JM");
    item_count -= too_small_items;
    if (item_count != details.stash_items) {
        return error.MissingItems;
    }

    if ((total_length / 8) + 2 != parser.buffer.len) {
        return error.CorruptStash;
    }

    try details.stash_size.append(.{
        .start_offset = parser.buffer.len * 8,
        .length = 0,
        .end_offset = 0,
    });

    parser.offset = 0;
}
