const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;
const verifyItemQuality = main.helper.verifyItemQuality;
const SaveIdentifiers = main.charsave.SaveIdentifiers;
const BasicItem = main.charsave.BasicItem;

const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const item_log = std.log.scoped(.Item);

const Parser = main.d2parser.D2SParser;
const ItemOffsetDetails = main.d2parser.ItemOffsetDetails;

const charsave = main.charsave;
const CharStatList = charsave.CharStatList;

const d2txt = main.d2txt;
const States = d2txt.States;

const ItemStats = main.isc.ItemStats;
const max_item_stat = main.isc.max_item_stat;

fn readCharacterName(parser: *Parser, item: *charsave.BasicItem) !void {
    @memset(&item.name, 0);
    for (0..16) |char| {
        item.name[char] = try parser.readBits(u8, 7);

        if (item.name[char] == 0) {
            break;
        }
    }
}

fn writeCharacterName(parser: *Parser, item: *charsave.BasicItem) void {
    for (0..16) |char| {
        parser.writeBits(7, item.name[char]);

        if (item.name[char] == 0) {
            break;
        }
    }
}

fn handleItemErrors(parser: *Parser, item: *BasicItem, err: anyerror) !void {
    const details = parser.item_details;
    const size_info: std.ArrayList(ItemOffsetDetails) = switch (item.item_source) {
        .player => details.player_size,
        .corpse => details.corpse_size,
        .mercenary => details.merc_size,
        .stash => details.stash_size,
        .golem => details.golem_size,
    };

    // item_log.err(
    //     "Found {s} | OFFSET: 0x{x}, INDEX: {d}, CODE: {s}, LOC: {s}, X/Y: {d}-{d}",
    //     .{
    //         @errorName(err),
    //         parser.offset / 8,
    //         item.index + 1,
    //         item.code,
    //         @tagName(item.inv_page),
    //         item.unit_x + 1,
    //         item.unit_y + 1,
    //     },
    // );

    switch (err) {
        error.BadStatOrder,
        error.InvalidSaveBits,
        error.InvalidItemLength,
        error.TooSmallItem,
        => {
            item.identifier = 0;

            if (item.is_socket) {
                const parent = item.parent_item orelse return error.MissingParentItem;
                parent.sockets -= 1;
                details.removed_items += 1;
            } else {
                var total_items: u8 = 0;
                if (item.sockets > 0) {
                    total_items += item.sockets;
                }
                details.current_index += total_items;
                item.sockets = 0;
                details.removed_items += 1 + total_items;
            }

            parser.offset = size_info.items[details.current_index].end_offset;

            return;
        },
        error.InvalidItemCode,
        error.InvalidInvPage,
        error.InvalidAnimationMode,
        error.InvalidEquipped,
        error.InvalidClass,
        error.BadStatIndex,
        => {
            // Currently unclear if these are fixable issues or not
            return err;
        },
        error.InvalidIdentifier => {
            // with the item bound checks this may not be possible anymore
            return err;
        },
        error.InvalidItemType => {
            // Almost guaranteed to mean there's an issue with the ingested .txt files
            // Not worth trying to "recover", as the problem is most likely _not_ the char file
            return err;
        },
        error.InvalidSocket => {
            // This means the item is (at least potentially) a good item but the parent item had
            // an invalid # of sockets, so a non-socket item was read as a socket.
            // After breaking out of the socket loop we need to be in the same start offset as before
            // but this time we'll read it as a "parent" item

            parser.offset = size_info.items[details.current_index].start_offset;
            details.current_index -= 1;

            const parent = item.parent_item orelse return error.MissingParentItem;
            parent.sockets = item.sock_index;
            parent.bad_socket = true;
            return;
        },
        else => {
            return err;
        },
    }
}

pub fn readItemList(parser: *Parser, items: *[]BasicItem) !void {
    const details = parser.item_details;

    const size_info: std.ArrayList(ItemOffsetDetails) = switch (items.*[0].item_source) {
        .player => details.player_size,
        .corpse => details.corpse_size,
        .mercenary => details.merc_size,
        .stash => details.stash_size,
        .golem => details.golem_size,
    };

    if (size_info.items.len == 0) {
        return error.NoItemSizeInfo;
    }

    for (items.*, 0..) |*item, i| {
        if (parser.offset == item.section_end_offset) {
            break;
        }

        if (main.log_item) {
            item_log.debug("ITEM: {d} of {d}, OFFSET: 0x{x}", .{ i + 1, items.len, parser.offset / 8 });
        }

        details.current_limit = size_info.items[details.current_index].end_offset;

        item.index = @as(u16, @intCast(i));
        item.max_index = @as(u16, @intCast(items.len));
        readItem(parser, item) catch |err| try handleItemErrors(parser, item, err);
        details.current_index += 1;

        if (item.sockets > 0) {
            item.socketed_items = try parser.allocator.alloc(charsave.BasicItem, item.sockets);
            for (item.socketed_items) |*sitem| {
                sitem.* = std.mem.zeroes(charsave.BasicItem);
                sitem.*.is_socket = true;
                sitem.*.item_source = item.item_source;
            }

            for (item.socketed_items, 0..) |*sock_item, s| {
                if (item.bad_socket or parser.offset == item.section_end_offset) {
                    break;
                }

                if (main.log_item) {
                    item_log.debug("SOCKET: {d} of {d}, OFFSET: 0x{x}", .{ s + 1, item.sockets, parser.offset / 8 });
                }

                if (details.current_index > size_info.items.len) {
                    return error.SizeInfoOutOfBounds;
                }
                details.current_limit = size_info.items[details.current_index].end_offset;

                sock_item.sock_index = @as(u8, @intCast(s));
                sock_item.parent_item = item;

                readItem(parser, sock_item) catch |err| try handleItemErrors(parser, sock_item, err);
                details.current_index += 1;
            }
        }
    }
    details.current_limit = 0;
}

test "Item: read bad item" {
    print("BAD ITEM\n\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    var buffer = [_]u8{
        0x4A, 0x4D, 0x10, 0x00, 0x80, 0x00, 0x65, 0x00, 0x06, 0xC2, 0x56, 0x76, 0x06, 0x02, 0xD2, 0xB9,
        0x95, 0xAA, 0xB1, 0xC9, 0x02, 0xCF, 0x9D, 0xA2, 0x99, 0x8A, 0x1F, 0xEA, 0xB2, 0xF0, 0xA9, 0x0C,
        0xC6, 0x9F, 0x2C, 0x64, 0x60, 0xC3, 0xC7, 0xDE, 0x52, 0x17, 0xDE, 0x1A, 0x6F, 0x42, 0x64, 0x51,
        0x24, 0xE0, 0x95, 0x02, 0x90, 0x68, 0x83, 0x59, 0xE4, 0xFF, // may need an additional 0x4A, 0x4D, here
    };
    parser.buffer = &buffer;

    parser.charsave.items.item = try parser.allocator.alloc(charsave.BasicItem, 1);
    for (parser.charsave.items.item) |*i| {
        i.* = std.mem.zeroes(charsave.BasicItem);
    }

    const item = &parser.charsave.items.item[0];
    try readItem(&parser, item);

    try expect(parser.offset == buffer.len * 8);
}

fn readItem(parser: *Parser, item: *charsave.BasicItem) !void {
    item.identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(item.identifier, .items);

    item.flags = @bitCast(try parser.readBits(u32, 32));
    item.format = try parser.readBits(u16, 10);

    const animation_mode: u8 = try parser.readBits(u8, 3);
    if (animation_mode > 6) {
        return error.InvalidAnimationMode;
    }
    item.animation_mode = @enumFromInt(animation_mode);

    if (item.animation_mode == .ground or item.animation_mode == .dropping) {
        item.unit_x = try parser.readBits(u16, 16);
        item.unit_y = try parser.readBits(u16, 16);
    } else {
        const equipped: u8 = try parser.readBits(u8, 4);
        if (equipped > 12) {
            return error.InvalidEquipped;
        }
        item.equipped = @enumFromInt(equipped);

        item.unit_x = try parser.readBits(u8, 4);
        item.unit_y = try parser.readBits(u8, 4);

        const inv_page: u8 = try parser.readBits(u8, 3) -% @as(u8, 1);
        if (inv_page > 5 and inv_page < 255) {
            return error.InvalidInvPage;
        }
        item.inv_page = @enumFromInt(inv_page);

        if (item.is_socket and item.inv_page != .null and item.animation_mode != .socketed) {
            return error.InvalidSocket;
        }
    }

    if (main.log_item) {
        item_log.debug(
            " X/Y: {d}-{d}, Equipped: {s}, Location: {s}, Mode: {s}",
            .{
                item.unit_x + 1,
                item.unit_y + 1,
                @tagName(item.equipped),
                @tagName(item.inv_page),
                @tagName(item.animation_mode),
            },
        );
        item_log.debug(" Flags: {any}", .{item.flags});
    }

    if (item.flags.compact) {
        try readItemsCompact(parser, item);
    } else {
        try readItemsExtended(parser, item);
    }
    parser.alignToByte();

    if (parser.item_details.current_limit != parser.offset) {
        return error.TooSmallItem;
    }
}

fn readItemsCompact(parser: *Parser, item: *charsave.BasicItem) !void {
    const version = parser.charsave.header.version;

    var quest: u8 = undefined;
    var quest_diff_check: u8 = undefined;

    if (item.flags.ear) {
        const ear_class: u8 = try parser.readBits(u8, 3);
        if (ear_class > 6) {
            return error.InvalidClass;
        }
        item.ear_class = @enumFromInt(ear_class);
        item.ear_level = try parser.readBits(u8, 7);
        try readCharacterName(parser, item);

        if (main.log_item) {
            item_log.debug(" (Ear) Class: {s}, Level: {d}, Name: {s}", .{ @tagName(item.ear_class), item.ear_level, item.name });
        }
    } else {
        try parser.readByteArray(&item.code);
        const item_code = std.mem.trim(u8, @as([]u8, &item.code), " ");

        var item_type: []u8 = undefined;

        if (parser.item_code_map.get(item_code)) |itype| {
            item_type = @as([]u8, itype.wam_type.items);
            quest = itype.quest;
            quest_diff_check = itype.questdiffcheck;
        } else {
            return error.InvalidItemCode;
        }

        var equiv_types: std.StringHashMap(bool) = undefined;
        if (parser.item_type_map.get(item_type)) |et| {
            equiv_types = et.equiv_types;
        } else {
            return error.InvalidItemType;
        }
        const is_gold: bool = equiv_types.contains(d2txt.ItemGenerics.gold);

        if (is_gold) {
            const is_big_gold: u8 = try parser.readBits(u8, 1);
            if (is_big_gold == 1) {
                _ = try parser.readBits(u32, 32);
            } else {
                _ = try parser.readBits(u32, 12);
            }
        }
    }

    if (version > 92) {
        if (quest > 0 and quest_diff_check == 1) {
            _ = try parser.readBits(u32, parser.isc_list.items[@intFromEnum(ItemStats.questitemdifficulty)].save_bits);
        }
    }

    const realm_info: u8 = try parser.readBits(u8, 1);
    if (version > 86 and realm_info != 0) {
        item.realm_data[0] = try parser.readBits(u32, 32);
        item.realm_data[1] = try parser.readBits(u32, 32);

        if (version > 93) {
            item.realm_data[2] = try parser.readBits(u32, 32);
        }
    }
}

fn readItemsExtended(parser: *Parser, item: *charsave.BasicItem) !void {
    try parser.readByteArray(&item.code);
    const item_code = std.mem.trim(u8, @as([]u8, &item.code), " ");
    var item_type: []u8 = undefined;
    var stackable: bool = false;

    if (parser.item_code_map.get(item_code)) |itype| {
        item_type = @as([]u8, itype.wam_type.items);
        stackable = itype.stackable;
    } else {
        return error.InvalidItemCode;
    }

    var equiv_types: std.StringHashMap(bool) = undefined;
    if (parser.item_type_map.get(item_type)) |et| {
        equiv_types = et.equiv_types;
    } else {
        return error.InvalidItemType;
    }

    const version = parser.charsave.header.version;
    const isc_list = parser.isc_list;

    const is_armor: bool = equiv_types.contains(d2txt.ItemGenerics.all_armor);
    const is_weapon: bool = equiv_types.contains(d2txt.ItemGenerics.all_weapons);
    const is_gold: bool = equiv_types.contains(d2txt.ItemGenerics.gold);

    item.sockets = try parser.readBits(u8, 3);
    item.seed = try parser.readBits(u32, 32);
    item.ilvl = try parser.readBits(u8, 7);
    item.quality = try verifyItemQuality(try parser.readBits(u8, 4));

    const has_gfx: u8 = try parser.readBits(u8, 1);
    if (has_gfx == 1) {
        item.custom_gfx = try parser.readBits(u8, 3);
    }

    const has_automagic: u8 = try parser.readBits(u8, 1);
    if (has_automagic == 1) {
        item.automagic = try parser.readBits(u16, 11);
    }

    switch (item.quality) {
        .inferior, .superior => {
            item.file_index = try parser.readBits(u32, 3);
        },
        .normal => {
            if (equiv_types.contains(d2txt.ItemGenerics.charm)) {
                const has_prefix: u8 = try parser.readBits(u8, 1);
                const affix: u32 = try parser.readBits(u32, 11);
                if (has_prefix == 1) {
                    item.magic_prefix[0] = affix;
                } else {
                    item.magic_suffix[0] = affix;
                }
            }

            if (equiv_types.contains(d2txt.ItemGenerics.body_part) and !equiv_types.contains(d2txt.ItemGenerics.player_body_part)) {
                item.file_index = try parser.readBits(u32, 10);
            }

            if (equiv_types.contains(d2txt.ItemGenerics.scroll) or equiv_types.contains(d2txt.ItemGenerics.book)) {
                item.magic_suffix[0] = try parser.readBits(u32, 5);
            }
        },
        .magic => {
            item.magic_prefix[0] = try parser.readBits(u32, 11);
            item.magic_suffix[0] = try parser.readBits(u32, 11);
        },
        .set, .unique => {
            item.file_index = try parser.readBits(u32, 12);
        },
        .rare, .crafted => {
            item.rare_prefix = try parser.readBits(u8, 8);
            item.rare_suffix = try parser.readBits(u8, 8);

            for (0..charsave.max_mods) |i| {
                const has_prefix: u8 = try parser.readBits(u8, 1);
                if (has_prefix == 1) {
                    item.magic_prefix[i] = try parser.readBits(u32, 11);
                } else {
                    item.magic_prefix[i] = 0;
                }

                const has_suffix: u8 = try parser.readBits(u8, 1);
                if (has_suffix == 1) {
                    item.magic_suffix[i] = try parser.readBits(u32, 11);
                } else {
                    item.magic_suffix[i] = 0;
                }
            }
        },
        .tempered => {
            item.rare_prefix = try parser.readBits(u8, 8);
            item.rare_suffix = try parser.readBits(u8, 8);
        },
        .invalid => {
            return error.InvalidItemQuality;
        },
    }

    var is_runeword: bool = false;
    if (item.flags.runeword) {
        is_runeword = true;
        item.magic_prefix[0] = try parser.readBits(u32, 16);
    }

    if (item.flags.ear) {
        const ear_class: u8 = try parser.readBits(u8, 3);
        if (ear_class > 6) {
            return error.InvalidEarClass;
        }
        item.ear_class = @enumFromInt(ear_class);
        item.ear_level = try parser.readBits(u8, 7);
        try readCharacterName(parser, item);
    } else if (item.flags.personalized) {
        try readCharacterName(parser, item);
    }

    const realm_info: u8 = try parser.readBits(u8, 1);
    if (version > 86 and realm_info != 0) {
        var realm_data: u32 = try parser.readBits(u32, 32);
        realm_data = try parser.readBits(u32, 32);

        if (version > 93) {
            realm_data = try parser.readBits(u32, 32);
        }
    }

    const defense = @intFromEnum(ItemStats.armorclass);
    const max_dura = @intFromEnum(ItemStats.maxdurability);
    const dura = @intFromEnum(ItemStats.durability);

    if (is_armor) {
        item.defense = try parser.readBits(u32, isc_list.items[defense].save_bits);
        item.max_durability = try parser.readBits(u32, isc_list.items[max_dura].save_bits);

        if (item.max_durability > 0) {
            item.durability = try parser.readBits(u32, isc_list.items[dura].save_bits);
        }
    } else if (is_weapon) {
        item.max_durability = try parser.readBits(u32, isc_list.items[max_dura].save_bits);

        if (item.max_durability > 0) {
            item.durability = try parser.readBits(u32, isc_list.items[dura].save_bits);
        }
    } else if (is_gold) {
        const is_big_gold: u8 = try parser.readBits(u8, 1);
        if (is_big_gold == 1) {
            _ = try parser.readBits(u32, 32);
        } else {
            _ = try parser.readBits(u32, 12);
        }
    }

    if (stackable) {
        if (version > 80) {
            item.quantity = try parser.readBits(u16, 9);
        } else {
            item.quantity = try parser.readBits(u16, 8);
        }
    }

    if (item.flags.socketed) {
        item.max_sockets = try parser.readBits(u32, isc_list.items[@intFromEnum(ItemStats.item_numsockets)].save_bits);
    }

    if (main.log_item) {
        item_log.debug(
            " Code: [{s}], Type: [{s}], Quality: {s}, Armor: {any}, Weapon: {any}",
            .{ item_code, item_type, @tagName(item.quality), is_armor, is_weapon },
        );
        item_log.debug(
            " Socketed: {any}, Sockets: {d}",
            .{ item.flags.socketed, item.sockets },
        );
    }

    item.total_statlists = 0;
    item.set_mask = 0;
    if (version > 84 and item.quality == .set) {
        item.total_statlists = 5;
        item.set_mask = try parser.readBits(u8, 5);
    }

    if (item.flags.runeword) {
        item.total_statlists += 1;
    }

    item.statlist = try parser.allocator.alloc(std.ArrayList(CharStatList), item.total_statlists + 1);
    for (item.statlist) |*sl| {
        sl.* = std.ArrayList(CharStatList).init(parser.allocator);
    }

    var state: i32 = 0;
    var flag: i32 = 0;
    var statlist_count: u5 = 0;
    var first_list: bool = true;

    while (first_list or statlist_count < item.total_statlists) {
        const statlist_u: u32 = @intCast(statlist_count);

        if (first_list) {
            state = 0;
            flag = 0x40;
            first_list = false;
        } else if (item.flags.runeword and statlist_count == item.total_statlists - 1) {
            state = @intFromEnum(States.runeword);
            flag = 0x40;
            statlist_count += 1;
        } else if (item.set_mask & (@as(u32, 1) << statlist_count) > 0) {
            state = States.set_states[statlist_u];
            flag = 0x2040;
            statlist_count += 1;
        } else {
            statlist_count += 1;
            continue;
        }

        const statlist = &item.statlist[statlist_count];

        var stat_id: u16 = 0;
        var last_stat_id: u16 = 0;
        var stat_index: u16 = 0;
        while (true) {
            stat_id = try parser.readBits(u16, 9);

            if (stat_id == max_item_stat) {
                break;
            }

            if (stat_id > max_item_stat) {
                return error.BadStatIndex;
            }

            if (stat_id < last_stat_id) {
                return error.BadStatOrder;
            }
            last_stat_id = stat_id;

            const save_bits: u16 = isc_list.items[stat_id].save_bits;
            const save_param_bits: u16 = isc_list.items[stat_id].save_param_bits;

            if (save_bits == 0) {
                return error.InvalidSaveBits;
            }

            if (main.log_item) {
                item_log.debug(
                    "  Idx:[{d}] (STAT_ID={d}: save={any}, param={any})",
                    .{ stat_index, stat_id, save_bits, save_param_bits },
                );
            }

            var min_value: u32 = 0;
            var max_value: u32 = 0;
            var len_value: u32 = 0;

            var save_value: u32 = 0;
            var param_value: u32 = 0;

            switch (@as(ItemStats, @enumFromInt(stat_id))) {
                .item_maxdamage_percent => {
                    const dam_max: u32 = @intFromEnum(ItemStats.item_maxdamage_percent);
                    const dam_min: u32 = @intFromEnum(ItemStats.item_mindamage_percent);
                    max_value = try parser.readBits(u32, isc_list.items[dam_max].save_bits);
                    min_value = try parser.readBits(u32, isc_list.items[dam_min].save_bits);

                    try statlist.append(.{ .id = dam_max, .value = max_value, .param = 0 });
                    try statlist.append(.{ .id = dam_min, .value = min_value, .param = 0 });
                    stat_index += 1;
                },
                .firemindam => {
                    const fire_min: u32 = @intFromEnum(ItemStats.firemindam);
                    const fire_max: u32 = @intFromEnum(ItemStats.firemaxdam);
                    min_value = try parser.readBits(u32, isc_list.items[fire_min].save_bits);
                    max_value = try parser.readBits(u32, isc_list.items[fire_max].save_bits);

                    try statlist.append(.{ .id = fire_min, .value = min_value, .param = 0 });
                    try statlist.append(.{ .id = fire_max, .value = max_value, .param = 0 });
                    stat_index += 1;
                },
                .lightmindam => {
                    const light_min: u32 = @intFromEnum(ItemStats.lightmindam);
                    const light_max: u32 = @intFromEnum(ItemStats.lightmaxdam);
                    min_value = try parser.readBits(u32, isc_list.items[light_min].save_bits);
                    max_value = try parser.readBits(u32, isc_list.items[light_max].save_bits);

                    try statlist.append(.{ .id = light_min, .value = min_value, .param = 0 });
                    try statlist.append(.{ .id = light_max, .value = max_value, .param = 0 });
                    stat_index += 1;
                },
                .magicmindam => {
                    const magic_min: u32 = @intFromEnum(ItemStats.magicmindam);
                    const magic_max: u32 = @intFromEnum(ItemStats.magicmaxdam);
                    min_value = try parser.readBits(u32, isc_list.items[magic_min].save_bits);
                    max_value = try parser.readBits(u32, isc_list.items[magic_max].save_bits);

                    try statlist.append(.{ .id = magic_min, .value = min_value, .param = 0 });
                    try statlist.append(.{ .id = magic_max, .value = max_value, .param = 0 });
                    stat_index += 1;
                },
                .coldmindam => {
                    const cold_min: u32 = @intFromEnum(ItemStats.coldmindam);
                    const cold_max: u32 = @intFromEnum(ItemStats.coldmaxdam);
                    const cold_len: u32 = @intFromEnum(ItemStats.coldlength);
                    min_value = try parser.readBits(u32, isc_list.items[cold_min].save_bits);
                    max_value = try parser.readBits(u32, isc_list.items[cold_max].save_bits);
                    len_value = try parser.readBits(u32, isc_list.items[cold_len].save_bits);

                    try statlist.append(.{ .id = cold_min, .value = min_value, .param = 0 });
                    try statlist.append(.{ .id = cold_max, .value = max_value, .param = 0 });
                    try statlist.append(.{ .id = cold_len, .value = len_value, .param = 0 });
                    stat_index += 2;
                },
                .poisonmindam => {
                    const pois_min: u32 = @intFromEnum(ItemStats.poisonmindam);
                    const pois_max: u32 = @intFromEnum(ItemStats.poisonmaxdam);
                    const pois_len: u32 = @intFromEnum(ItemStats.poisonlength);
                    min_value = try parser.readBits(u32, isc_list.items[pois_min].save_bits);
                    max_value = try parser.readBits(u32, isc_list.items[pois_max].save_bits);
                    len_value = try parser.readBits(u32, isc_list.items[pois_len].save_bits);

                    try statlist.append(.{ .id = pois_min, .value = min_value, .param = 0 });
                    try statlist.append(.{ .id = pois_max, .value = max_value, .param = 0 });
                    try statlist.append(.{ .id = pois_len, .value = len_value, .param = 0 });
                    stat_index += 2;
                },
                else => {
                    if (save_param_bits > 0) {
                        param_value = try parser.readBits(u32, save_param_bits);
                    }

                    save_value = try parser.readBits(u32, save_bits);

                    try statlist.append(.{ .id = stat_id, .value = save_value, .param = param_value });
                },
            }
            stat_index += 1;
        }
    }
}

pub fn writeItemList(parser: *Parser, items: *[]BasicItem) !u16 {
    var item_count: u16 = 0;
    for (items.*, 0..) |*item, i| {
        if (item.identifier == 0) {
            continue;
        }

        if (main.log_item) {
            item_log.debug("ITEM(write): {d} of {d}, OFFSET: 0x{x}", .{ i + 1, items.len, parser.out_offset / 8 });
        }

        item_count += 1;
        try writeItem(parser, item);

        if (item.sockets > 0) {
            for (item.socketed_items, 0..) |*sock_item, s| {
                if (sock_item.identifier == 0 or s == item.sockets) {
                    continue;
                }

                if (main.log_item) {
                    item_log.debug("SOCKET(write): {d} of {d}, OFFSET: 0x{x}", .{ s + 1, item.sockets, parser.out_offset / 8 });
                }
                try writeItem(parser, sock_item);
            }
        }
    }

    return item_count;
}

fn writeItem(parser: *Parser, item: *charsave.BasicItem) !void {
    parser.writeBits(16, item.identifier);

    const flags: u32 = @bitCast(item.flags);
    parser.writeBits(32, flags);
    parser.writeBits(10, item.format);

    const anim: u8 = @intFromEnum(item.animation_mode);
    parser.writeBits(3, anim);

    if (item.animation_mode == .ground or item.animation_mode == .dropping) {
        parser.writeBits(16, item.unit_x);
        parser.writeBits(16, item.unit_y);
    } else {
        parser.writeBits(4, @intFromEnum(item.equipped));
        parser.writeBits(4, item.unit_x);
        parser.writeBits(4, item.unit_y);
        parser.writeBits(3, @intFromEnum(item.inv_page) +% @as(u8, 1));
    }

    if (item.flags.compact) {
        try writeItemsCompact(parser, item);
    } else {
        try writeItemsExtended(parser, item);
    }
    parser.padToByte();
}

fn writeItemsCompact(parser: *Parser, item: *charsave.BasicItem) !void {
    const version = parser.charsave.header.version;
    var quest: u8 = undefined;
    var quest_diff_check: u8 = undefined;

    if (item.flags.ear) {
        parser.writeBits(3, @intFromEnum(item.ear_class));
        parser.writeBits(7, item.ear_level);
        writeCharacterName(parser, item);
    } else {
        parser.writeByteArray(&item.code);

        const item_code = std.mem.trim(u8, @as([]u8, &item.code), " ");
        var item_type: []u8 = undefined;

        if (parser.item_code_map.get(item_code)) |itype| {
            item_type = @as([]u8, itype.wam_type.items);
            quest = itype.quest;
            quest_diff_check = itype.questdiffcheck;
        } else {
            return error.InvalidItemCode;
        }

        var equiv_types: std.StringHashMap(bool) = undefined;
        if (parser.item_type_map.get(item_type)) |et| {
            equiv_types = et.equiv_types;
        } else {
            return error.InvalidItemType;
        }

        if (equiv_types.contains(d2txt.ItemGenerics.gold)) {
            parser.writeBits(1, @as(u32, 1));
        }
    }

    if (version > 92) {
        if (quest > 0 and quest_diff_check == 1) {
            _ = try parser.readBits(u32, parser.isc_list.items[@intFromEnum(ItemStats.questitemdifficulty)].save_bits);
        }
    }

    const has_realm: u1 = if (item.realm_data[0] != 0) 1 else 0;
    parser.writeBits(1, has_realm);
    if (version > 86 and item.realm_data[0] != 0) {
        parser.writeBits(32, item.realm_data[0]);
        parser.writeBits(32, item.realm_data[1]);

        if (version > 93) {
            parser.writeBits(32, item.realm_data[2]);
        }
    }
}

fn writeItemsExtended(parser: *Parser, item: *charsave.BasicItem) !void {
    const version = parser.charsave.header.version;
    const isc_list = parser.isc_list;

    parser.writeByteArray(&item.code);

    const item_code = std.mem.trim(u8, @as([]u8, &item.code), " ");
    var item_type: []u8 = undefined;
    var stackable: bool = false;
    var inv_gfx: u32 = 0;

    if (parser.item_code_map.get(item_code)) |itype| {
        item_type = @as([]u8, itype.wam_type.items);
        stackable = itype.stackable;
    } else {
        return error.InvalidItemCode;
    }

    var equiv_types: std.StringHashMap(bool) = undefined;
    if (parser.item_type_map.get(item_type)) |et| {
        equiv_types = et.equiv_types;
        inv_gfx = et.inv_gfx;
    } else {
        return error.InvalidItemType;
    }

    const is_armor: bool = equiv_types.contains(d2txt.ItemGenerics.all_armor);
    const is_weapon: bool = equiv_types.contains(d2txt.ItemGenerics.all_weapons);
    const is_gold: bool = equiv_types.contains(d2txt.ItemGenerics.gold);

    parser.writeBits(3, item.sockets);
    parser.writeBits(32, item.seed);
    parser.writeBits(7, item.ilvl);
    parser.writeBits(4, @intFromEnum(item.quality));

    const has_gfx: u1 = if (inv_gfx != 0) 1 else 0;
    parser.writeBits(1, has_gfx);
    if (inv_gfx != 0) {
        parser.writeBits(3, item.custom_gfx);
    }

    if (item.automagic != 0) {
        parser.writeBits(1, @as(u32, 1));
        parser.writeBits(11, item.automagic);
    } else {
        parser.writeBits(1, @as(u32, 0));
    }

    switch (item.quality) {
        .inferior, .superior => {
            parser.writeBits(3, item.file_index);
        },
        .normal => {
            if (equiv_types.contains(d2txt.ItemGenerics.charm)) {
                const has_prefix: u1 = if (item.magic_prefix[0] != 0) 1 else 0;
                parser.writeBits(1, has_prefix);

                if (item.magic_prefix[0] != 0) {
                    parser.writeBits(11, item.magic_prefix[0]);
                } else {
                    parser.writeBits(11, item.magic_suffix[0]);
                }
            }

            if (equiv_types.contains(d2txt.ItemGenerics.body_part) and !equiv_types.contains(d2txt.ItemGenerics.player_body_part)) {
                parser.writeBits(10, item.file_index);
            }

            if (equiv_types.contains(d2txt.ItemGenerics.scroll) or equiv_types.contains(d2txt.ItemGenerics.book)) {
                parser.writeBits(5, item.magic_suffix[0]);
            }
        },
        .magic => {
            parser.writeBits(11, item.magic_prefix[0]);
            parser.writeBits(11, item.magic_suffix[0]);
        },
        .set, .unique => {
            parser.writeBits(12, item.file_index);
        },
        .rare, .crafted => {
            parser.writeBits(8, item.rare_prefix);
            parser.writeBits(8, item.rare_suffix);

            for (0..charsave.max_mods) |i| {
                if (item.magic_prefix[i] != 0) {
                    parser.writeBits(1, @as(u32, 1));
                    parser.writeBits(11, item.magic_prefix[i]);
                } else {
                    parser.writeBits(1, @as(u32, 0));
                }

                if (item.magic_suffix[i] != 0) {
                    parser.writeBits(1, @as(u32, 1));
                    parser.writeBits(11, item.magic_suffix[i]);
                } else {
                    parser.writeBits(1, @as(u32, 0));
                }
            }
        },
        .tempered => {
            parser.writeBits(8, item.rare_prefix);
            parser.writeBits(8, item.rare_suffix);
        },
        .invalid => {
            return error.InvalidItemQuality;
        },
    }

    if (item.flags.runeword) {
        parser.writeBits(16, item.magic_prefix[0]);
    }

    if (item.flags.ear) {
        parser.writeBits(3, @intFromEnum(item.ear_class));
        parser.writeBits(7, item.ear_level);
        writeCharacterName(parser, item);
    } else if (item.flags.personalized) {
        writeCharacterName(parser, item);
    }

    const has_realm: u1 = if (item.realm_data[0] != 0) 1 else 0;
    parser.writeBits(1, has_realm);
    if (version > 86 and item.realm_data[0] != 0) {
        parser.writeBits(32, item.realm_data[0]);
        parser.writeBits(32, item.realm_data[1]);

        if (version > 93) {
            parser.writeBits(32, item.realm_data[2]);
        }
    }

    const defense = @intFromEnum(ItemStats.armorclass);
    const max_dura = @intFromEnum(ItemStats.maxdurability);
    const dura = @intFromEnum(ItemStats.durability);

    if (is_armor) {
        parser.writeBits(isc_list.items[defense].save_bits, item.defense);
        parser.writeBits(isc_list.items[max_dura].save_bits, item.max_durability);

        if (item.max_durability > 0) {
            parser.writeBits(isc_list.items[dura].save_bits, item.durability);
        }
    } else if (is_weapon) {
        parser.writeBits(isc_list.items[max_dura].save_bits, item.max_durability);

        if (item.max_durability > 0) {
            parser.writeBits(isc_list.items[dura].save_bits, item.durability);
        }
    } else if (is_gold) {
        parser.writeBits(1, @as(u32, 1));
    }

    if (stackable) {
        if (version > 80) {
            parser.writeBits(9, item.quantity);
        } else {
            parser.writeBits(8, item.quantity);
        }
    }

    if (item.flags.socketed) {
        parser.writeBits(isc_list.items[@intFromEnum(ItemStats.item_numsockets)].save_bits, item.max_sockets);
    }

    if (item.quality == .set) {
        parser.writeBits(5, item.set_mask);
    }

    const dam_max: u32 = @intFromEnum(ItemStats.item_maxdamage_percent);
    const dam_min: u32 = @intFromEnum(ItemStats.item_mindamage_percent);
    const fire_min: u32 = @intFromEnum(ItemStats.firemindam);
    const fire_max: u32 = @intFromEnum(ItemStats.firemaxdam);

    const light_min: u32 = @intFromEnum(ItemStats.lightmindam);
    const light_max: u32 = @intFromEnum(ItemStats.lightmaxdam);
    const magic_min: u32 = @intFromEnum(ItemStats.magicmindam);
    const magic_max: u32 = @intFromEnum(ItemStats.magicmaxdam);

    const cold_min: u32 = @intFromEnum(ItemStats.coldmindam);
    const cold_max: u32 = @intFromEnum(ItemStats.coldmaxdam);
    const cold_len: u32 = @intFromEnum(ItemStats.coldlength);
    const pois_min: u32 = @intFromEnum(ItemStats.poisonmindam);
    const pois_max: u32 = @intFromEnum(ItemStats.poisonmaxdam);
    const pois_len: u32 = @intFromEnum(ItemStats.poisonlength);

    var state: i32 = 0;
    var flag: i32 = 0;
    var statlist_count: u5 = 0;
    var first_list: bool = true;

    while (first_list or statlist_count < item.total_statlists) {
        const statlist_u: u32 = @intCast(statlist_count);

        if (first_list) {
            state = 0;
            flag = 0x40;
            first_list = false;
        } else if (item.flags.runeword and statlist_count == item.total_statlists - 1) {
            state = @intFromEnum(States.runeword);
            flag = 0x40;
            statlist_count += 1;
        } else if (item.set_mask & (@as(u32, 1) << statlist_count) > 0) {
            state = States.set_states[statlist_u];
            flag = 0x2040;
            statlist_count += 1;
        } else {
            statlist_count += 1;
            continue;
        }

        const statlist = &item.statlist[statlist_count];

        for (statlist.items, 0..) |stat, i| {
            if (stat.id == dam_min or
                stat.id == fire_max or
                stat.id == light_max or
                stat.id == magic_max or
                stat.id == cold_max or
                stat.id == cold_len or
                stat.id == pois_max or
                stat.id == pois_len)
            {
                continue;
            }

            const save_bits: u16 = isc_list.items[stat.id].save_bits;
            const save_param_bits: u16 = isc_list.items[stat.id].save_param_bits;

            parser.writeBits(9, @as(u9, @intCast(stat.id)));

            var min_stat: u32 = 0;
            var max_stat: u32 = 0;
            var len_stat: u32 = 0;

            switch (@as(ItemStats, @enumFromInt(stat.id))) {
                .item_maxdamage_percent => {
                    min_stat = statlist.items[i + 1].value;
                    parser.writeBits(isc_list.items[dam_max].save_bits, stat.value);
                    parser.writeBits(isc_list.items[dam_min].save_bits, min_stat);
                },
                .firemindam => {
                    max_stat = statlist.items[i + 1].value;
                    parser.writeBits(isc_list.items[fire_min].save_bits, stat.value);
                    parser.writeBits(isc_list.items[fire_max].save_bits, max_stat);
                },
                .lightmindam => {
                    max_stat = statlist.items[i + 1].value;

                    parser.writeBits(isc_list.items[light_min].save_bits, stat.value);
                    parser.writeBits(isc_list.items[light_max].save_bits, max_stat);
                },
                .magicmindam => {
                    max_stat = statlist.items[i + 1].value;
                    parser.writeBits(isc_list.items[magic_min].save_bits, stat.value);
                    parser.writeBits(isc_list.items[magic_max].save_bits, max_stat);
                },
                .coldmindam => {
                    max_stat = statlist.items[i + 1].value;
                    len_stat = statlist.items[i + 2].value;

                    parser.writeBits(isc_list.items[cold_min].save_bits, stat.value);
                    parser.writeBits(isc_list.items[cold_max].save_bits, max_stat);
                    parser.writeBits(isc_list.items[cold_len].save_bits, len_stat);
                },
                .poisonmindam => {
                    max_stat = statlist.items[i + 1].value;
                    len_stat = statlist.items[i + 2].value;
                    parser.writeBits(isc_list.items[pois_min].save_bits, stat.value);
                    parser.writeBits(isc_list.items[pois_max].save_bits, max_stat);
                    parser.writeBits(isc_list.items[pois_len].save_bits, len_stat);
                },
                else => {
                    if (save_param_bits > 0) {
                        parser.writeBits(save_param_bits, stat.param);
                    }

                    parser.writeBits(save_bits, stat.value);
                },
            }
        }

        parser.writeBits(9, max_item_stat);
    }
}
