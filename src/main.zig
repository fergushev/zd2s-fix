const std = @import("std");
const splitSequence = std.mem.splitSequence;
const main_log = std.log.scoped(.Main);

pub const helper = @import("helper.zig");
const calcChecksum = helper.calcChecksum;
const getItemDetails = helper.getItemDetails;
const getStashItemDetails = helper.getStashItemDetails;
const verifyIdentifier = helper.verifyIdentifier;
const loadCharSave = helper.loadCharSave;
pub const zcsv = @import("zcsv");

const print = std.debug.print;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub const charsave = @import("character_save.zig");
const Stats = charsave.Stats;
const SaveFlags = charsave.SaveFlags;

pub const isc = @import("itemstat.zig");
const ItemStats = isc.ItemStats;

pub const d2txt = @import("d2txt.zig");
const ItemStatCostTxt = d2txt.ItemStatCostTxt;
const States = d2txt.States;

pub const d2parser = @import("parser.zig");
const Parser = d2parser.D2SParser;

pub const parse_character = @import("parse/character.zig");
const readCharacterData = parse_character.readCharacterData;
const readEquipment = parse_character.readEquipment;
const readCharacterStats = parse_character.readCharacterStats;
const readCharacterSkills = parse_character.readCharacterSkills;
const readCharacterItems = parse_character.readCharacterItems;

const writeCharacterData = parse_character.writeCharacterData;
const writeEquipment = parse_character.writeEquipment;
const writeCharacterStats = parse_character.writeCharacterStats;
const writeCharacterSkills = parse_character.writeCharacterSkills;
const writeCharacterItems = parse_character.writeCharacterItems;

pub const parse_corpse = @import("parse/corpse.zig");
const readCorpseItems = parse_corpse.readCorpseItems;
const writeCorpseItems = parse_corpse.writeCorpseItems;

pub const parse_golem = @import("parse/golem.zig");
const readGolemItems = parse_golem.readGolemItems;
const writeGolemItems = parse_golem.writeGolemItems;

pub const parse_guild = @import("parse/guild.zig");
const readGuild = parse_guild.readGuild;
const writeGuild = parse_guild.writeGuild;

pub const parse_header = @import("parse/header.zig");
const readHeader = parse_header.readHeader;
const writeHeader = parse_header.writeHeader;
const updateHeader = parse_header.updateHeader;

pub const parse_item = @import("parse/item.zig");

pub const parse_hotkey = @import("parse/hotkey.zig");
const readHotkeys = parse_hotkey.readHotkeys;
const readMouseSkills = parse_hotkey.readMouseSkills;
const writeHotkeys = parse_hotkey.writeHotkeys;
const writeMouseSkills = parse_hotkey.writeMouseSkills;

pub const parse_mercenary = @import("parse/mercenary.zig");
const readMercenary = parse_mercenary.readMercenary;
const readMercenaryItems = parse_mercenary.readMercenaryItems;
const writeMercenary = parse_mercenary.writeMercenary;
const writeMercenaryItems = parse_mercenary.writeMercenaryItems;

pub const parse_quest = @import("parse/quest.zig");
const readQuest = parse_quest.readQuest;
const readNPCIntro = parse_quest.readNPCIntro;
const writeQuest = parse_quest.writeQuest;
const writeNPCIntro = parse_quest.writeNPCIntro;

pub const parse_stash = @import("parse/stash.zig");
const readStashItems = parse_stash.readStashItems;
const writeStashItems = parse_stash.writeStashItems;

pub const parse_waypoint = @import("parse/waypoint.zig");
const readMapInfo = parse_waypoint.readMapInfo;
const readWaypoint = parse_waypoint.readWaypoint;
const writeMapInfo = parse_waypoint.writeMapInfo;
const writeWaypoint = parse_waypoint.writeWaypoint;

pub fn readExtraData(parser: *Parser) !void {
    if (parser.buffer.len != parser.offset / 8) {
        parser.charsave.extra.has_extra = true;
        parser.charsave.extra.buffer = try parser.allocator.alloc(u8, parser.buffer.len - (parser.offset / 8));
        for (0..parser.buffer.len - (parser.offset / 8)) |i| {
            parser.charsave.extra.buffer[i] = try parser.readBits(u8, 8);
        }
    }
}

pub fn writeExtraData(parser: *Parser) !void {
    if (parser.charsave.extra.has_extra) {
        parser.writeByteArray(parser.charsave.extra.buffer);
    }
}

pub const log_character = false;
pub const log_corpse = false;
pub const log_golem = false;
pub const log_header = false;
pub const log_hotkey = false;
pub const log_item = false;
pub const log_mercenary = false;
pub const log_quest = false;
pub const log_stash = false;
pub const log_waypoint = false;

pub const std_options = .{
    .log_level = .err,
};

const ValidExtensions = enum {
    @".d2s",
    stash,
    @"stash.hc",
    @"stash.nl",
    @"stash.hc.nl",
    invalid,
};

pub fn main() !void {
    var arena_main = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_main.deinit();
    const allocator_main = arena_main.allocator();

    const isc_list = try d2txt.getItemStatCostTxt(allocator_main);
    const wam_list = try d2txt.getWamTxt(allocator_main);
    const itypes_list = try d2txt.getItemTypesTxt(allocator_main);

    const item_code_map = try d2txt.createItemCodeMap(allocator_main, wam_list);
    const item_type_map = try d2txt.createItemTypeMap(allocator_main, itypes_list);

    const out_buffer: []u8 = try allocator_main.alloc(u8, 0x4000 * 10);
    @memset(out_buffer, 0);

    const args = try std.process.argsAlloc(allocator_main);
    defer std.process.argsFree(allocator_main, args);

    const expected_args: usize = 4;
    if (args.len != expected_args) {
        main_log.err("Too few args passed. Expected {d}, got {d}", .{ expected_args, args.len });
        main_log.err("Required positional args: read_only(0|1) file_type(char|stash) absolute_dir_path(path string)", .{});
        return;
    }

    const read_only = try std.fmt.parseInt(u32, args[1], 10);
    if (read_only != 0 and read_only != 1) {
        main_log.err("read_only value was invalid. Expected 0 or 1, got {d}", .{read_only});
        return;
    }

    const read_type = args[2];
    const valid_type = (std.mem.eql(u8, read_type, "char") or std.mem.eql(u8, read_type, "stash"));
    if (!valid_type) {
        main_log.err("file_type value was invalid. Expected char or stash, got {s}", .{read_type});
        return;
    }

    const file_path = args[3];
    if (file_path.len < 10) {
        main_log.err("Absolute path length was too small: {d}", .{file_path.len});
        return;
    }

    var dir = try std.fs.openDirAbsolute(file_path, .{ .iterate = true });
    defer dir.close();

    var dir_walker = try dir.walk(allocator_main);
    defer dir_walker.deinit();

    if (std.mem.eql(u8, read_type, "char")) {
        var char_timer = try std.time.Timer.start();
        var char_count: u32 = 0;
        while (try dir_walker.next()) |entry| {
            char_count += 1;
            if (entry.kind == .file) {
                @memset(out_buffer, 0);
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();
                const allocator = arena.allocator();

                var parser = try Parser.init(
                    allocator,
                    try loadCharSave(allocator, entry.dir, entry.basename),
                    out_buffer,
                    isc_list,
                    wam_list,
                    itypes_list,
                    item_code_map,
                    item_type_map,
                );

                const orig_checksum = validateCharfile(&parser) catch |err| try {
                    switch (err) {
                        error.InvalidCharfile, error.InvalidIdentifier => {
                            continue;
                        },
                        else => {
                            main_log.err("Error: {s}. Invalid file: {s}", .{ @errorName(err), entry.path });
                            continue;
                        },
                    }
                };

                const ladder: bool = try isLadderChar(&parser);
                if (!ladder) {
                    readD2S(&parser) catch |err| try {
                        main_log.err("Error: {s}. Failed to read file: {s}", .{ @errorName(err), entry.path });
                        continue;
                    };

                    if (parser.item_details.removed_items == 0) {
                        // No broken items, nothing to fix
                        continue;
                    }

                    const new_checksum: u32 = writeD2S(&parser) catch |err| try {
                        main_log.err("Error: {s}. Failed to write file: {s}", .{ @errorName(err), entry.path });
                        continue;
                    };

                    if (try checksumsMatch(orig_checksum, new_checksum)) {
                        main_log.err(
                            "Checksums match but file has changed. Bad Items: {d}, File: {s}",
                            .{ parser.item_details.removed_items, entry.path },
                        );
                        continue;
                    }

                    if (read_only == 0) {
                        const char_file = try entry.dir.openFile(entry.basename, .{ .mode = .read_write });

                        const size: u32 = @as(u32, @intCast(parser.out_offset)) / 8;
                        try char_file.writeAll(parser.out_buffer[0..size]);
                        try char_file.setEndPos(size);
                        defer char_file.close();
                    } else {
                        main_log.err("Broken items: {d}: File: {s}", .{ parser.item_details.removed_items, entry.path });
                    }
                }
            }
        }
        const char_time_end = char_timer.read();
        main_log.err("Total time: {d} seconds | Count: {d}", .{ char_time_end / 1_000_000_000, char_count });
    } else if (std.mem.eql(u8, read_type, "stash")) {
        var stash_timer = try std.time.Timer.start();
        var stash_count: u32 = 0;
        while (try dir_walker.next()) |entry| {
            if (entry.kind == .file and std.mem.eql(u8, std.fs.path.extension(entry.basename), ".nl")) {
                var ext_it = splitSequence(u8, entry.basename, ".");
                _ = ext_it.first();
                const extension = ext_it.rest();

                const ext = std.meta.stringToEnum(ValidExtensions, extension) orelse continue;
                switch (ext) {
                    .@"stash.nl", .@"stash.hc.nl" => {
                        stash_count += 1;
                        @memset(out_buffer, 0);

                        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                        defer arena.deinit();
                        const allocator = arena.allocator();

                        var parser = try Parser.init(
                            allocator,
                            try loadCharSave(allocator, entry.dir, entry.basename),
                            out_buffer,
                            isc_list,
                            wam_list,
                            itypes_list,
                            item_code_map,
                            item_type_map,
                        );

                        validateStashfile(&parser) catch |err| try {
                            switch (err) {
                                error.InvalidStashfile, error.NoStashItems, error.InvalidIdentifier => {
                                    continue;
                                },
                                else => {
                                    main_log.err("Error: {s}. Invalid file: {s}", .{ @errorName(err), entry.path });
                                    continue;
                                },
                            }
                        };

                        readStash(&parser) catch |err| try {
                            main_log.err("Error: {s}. Failed to read file: {s}", .{ @errorName(err), entry.path });
                            continue;
                        };

                        if (parser.item_details.removed_items == 0) {
                            // No broken items, no need to rewrite
                            continue;
                        }

                        writeStash(&parser) catch |err| try {
                            main_log.err("Error: {s}. Failed to write file: {s}", .{ @errorName(err), entry.path });
                            continue;
                        };

                        if (read_only == 0) {
                            const stash_file = try entry.dir.openFile(entry.path, .{ .mode = .read_write });

                            const size: u32 = @as(u32, @intCast(parser.out_offset)) / 8;
                            try stash_file.writeAll(parser.out_buffer[0..size]);
                            try stash_file.setEndPos(size);
                            defer stash_file.close();
                        } else {
                            main_log.err("Broken items: {d}: File: {s}", .{ parser.item_details.removed_items, entry.path });
                        }
                    },
                    else => {
                        main_log.err("Ladder Stash. File: {s}", .{entry.path});
                        continue;
                    },
                }
            }
        }
        const stash_time_end = stash_timer.read();
        main_log.err("Total time: {d} seconds | Count: {d}", .{ stash_time_end / 1_000_000_000, stash_count });
    }
}

test {
    std.testing.refAllDecls(@This());
}

fn validateCharfile(parser: *Parser) !u32 {
    if (parser.buffer.len < 512) {
        return error.InvalidCharfile;
    }

    const identifier = try parser.readBits(u32, 32);
    parser.offset = 96;
    try verifyIdentifier(identifier, .save);

    const checksum: u32 = try parser.readBits(u32, 32);
    parser.offset = 0;

    return checksum;
}

fn validateStashfile(parser: *Parser) !void {
    if (parser.buffer.len < 4) {
        return error.InvalidStashfile;
    }

    const count = try parser.readBits(u16, 16);
    if (count == 0) {
        return error.NoStashItems;
    }

    const identifier = try parser.readBits(u16, 16);
    try verifyIdentifier(identifier, .items);
    parser.offset = 0;
}

fn isLadderChar(parser: *Parser) !bool {
    parser.offset = 288;
    const save_flags: SaveFlags = @bitCast(try parser.readBits(u32, 32));
    parser.offset = 0;

    return save_flags.ladder;
}

fn checksumsMatch(before: u32, after: u32) !bool {
    if (before == after) {
        return true;
    }
    return false;
}

fn readD2S(parser: *Parser) !void {
    try readHeader(parser);
    try readCharacterData(parser);
    try readHotkeys(parser);
    try readMouseSkills(parser);
    try readEquipment(parser);

    try readMapInfo(parser);

    try readMercenary(parser);
    try readGuild(parser);

    try readQuest(parser);
    try readWaypoint(parser);
    try readNPCIntro(parser);

    // Everything before this point is a static size, the rest varies
    // Should add some offset constants for the above so you can read specific things
    // without having to read the entire file.
    // (i.e. parse hotkeys but nothing else)
    try readCharacterStats(parser);
    try readCharacterSkills(parser);

    try getItemDetails(parser);
    try readCharacterItems(parser);
    try readCorpseItems(parser);
    if (parser.charsave.character_data.save_flags.expansion) {
        try readMercenaryItems(parser);
        try readGolemItems(parser);
    }

    try readExtraData(parser);
}

fn writeD2S(parser: *Parser) !u32 {
    writeHeader(parser);
    writeCharacterData(parser);
    writeHotkeys(parser);
    writeMouseSkills(parser);
    writeEquipment(parser);

    try writeMapInfo(parser);

    try writeMercenary(parser);
    try writeGuild(parser);

    try writeQuest(parser);
    try writeWaypoint(parser);
    try writeNPCIntro(parser);

    writeCharacterStats(parser);
    writeCharacterSkills(parser);
    try writeCharacterItems(parser);
    try writeCorpseItems(parser);
    if (parser.charsave.character_data.save_flags.expansion) {
        try writeMercenaryItems(parser);
        try writeGolemItems(parser);
    }

    try writeExtraData(parser);
    const checksum: u32 = try updateHeader(parser);
    return checksum;
}

fn readStash(parser: *Parser) !void {
    try getStashItemDetails(parser);
    try readStashItems(parser);
}

fn writeStash(parser: *Parser) !void {
    try writeStashItems(parser);
}
