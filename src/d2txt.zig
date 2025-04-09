const main = @import("main.zig");

const std = @import("std");
const print = std.debug.print;

const zcsv = main.zcsv;
const fieldToInt = zcsv.decode.fieldToInt;
const fieldToStr = zcsv.decode.fieldToStr;
const fieldToBool = zcsv.decode.fieldToBool;
const StrRes = zcsv.decode.StrRes;
const Parser = zcsv.allocs.map.Parser;

const helper = main.helper;
const findAllEquivalentTypes = helper.findAllEquivalentTypes;

pub const TxtNames = struct {
    const item_stat_cost: []const u8 = "txt/ItemStatCost.txt";
    const item_types: []const u8 = "txt/ItemTypes.txt";
    const weapons: []const u8 = "txt/Weapons.txt";
    const armor: []const u8 = "txt/Armor.txt";
    const misc: []const u8 = "txt/Misc.txt";
};

pub const ItemGenerics = struct {
    pub const all_armor: []const u8 = "armo";
    pub const all_weapons: []const u8 = "weap";
    pub const gold: []const u8 = "gold";
    pub const sock: []const u8 = "sock";
    pub const charm: []const u8 = "char";
    pub const body_part: []const u8 = "body";
    pub const player_body_part: []const u8 = "play";
    pub const book: []const u8 = "book";
    pub const scroll: []const u8 = "scro";
};

pub const ItemStatCostTxt = struct {
    const Self = @This();

    stat: std.ArrayList(u8),
    id: u16,
    saved: u16,
    csv_signed: u16,
    csv_bits: u16,
    csv_param: u16,
    save_bits_109: u16,
    save_add_109: u16,
    save_bits: u16,
    save_add: i16,
    save_param_bits: u16,

    pub fn deinit(self: *Self) void {
        self.stat.deinit();
    }
};

pub fn getItemStatCostTxt(allocator: std.mem.Allocator) !*std.ArrayList(ItemStatCostTxt) {
    const isc_txt = try std.fs.cwd().openFile(TxtNames.item_stat_cost, .{});
    defer isc_txt.close();

    var parser = try zcsv.allocs.map.init(allocator, isc_txt.reader(), .{ .column_delim = '\t' });
    defer parser.deinit();

    const isc_array = try allocator.create(std.ArrayList(ItemStatCostTxt));
    isc_array.* = std.ArrayList(ItemStatCostTxt).init(allocator);

    while (parser.next()) |row| {
        defer row.deinit();
        const stat = row.data().get("Stat") orelse return error.MissingStat;
        var id = try fieldToInt(u16, row.data().get("ID") orelse return error.MissingUserId, 10);

        var saved = try fieldToInt(u16, row.data().get("Saved") orelse return error.MissingSaved, 10);
        var csv_signed = try fieldToInt(u16, row.data().get("CSvSigned") orelse return error.MissingCSvSigned, 10);
        var csv_bits = try fieldToInt(u16, row.data().get("CSvBits") orelse return error.MissingCSvBits, 10);
        var csv_param = try fieldToInt(u16, row.data().get("CSvParam") orelse return error.MissingCSvParam, 10);

        var save_bits = try fieldToInt(u16, row.data().get("Save Bits") orelse return error.MissingSaveBits, 10);
        var save_add = try fieldToInt(i16, row.data().get("Save Add") orelse return error.MissingSaveAdd, 10);
        var save_param_bits = try fieldToInt(u16, row.data().get("Save Param Bits") orelse return error.MissingSaveParamBits, 10);

        id = if (id != null) id else 0;

        saved = if (saved != null) saved else 0;
        csv_signed = if (csv_signed != null) csv_signed else 0;
        csv_bits = if (csv_bits != null) csv_bits else 0;
        csv_param = if (csv_param != null) csv_param else 0;

        save_bits = if (save_bits != null) save_bits else 0;
        save_add = if (save_add != null) save_add else 0;
        save_param_bits = if (save_param_bits != null) save_param_bits else 0;

        try isc_array.append(ItemStatCostTxt{
            .stat = try stat.clone(allocator),
            .id = id.?,

            .saved = saved.?,
            .csv_signed = csv_signed.?,
            .csv_bits = csv_bits.?,
            .csv_param = csv_param.?,

            .save_bits_109 = 0,
            .save_add_109 = 0,

            .save_bits = save_bits.?,
            .save_add = save_add.?,
            .save_param_bits = save_param_bits.?,
        });
    }

    return isc_array;
}

pub const ItemTypesTxt = struct {
    const Self = @This();

    index: u32,
    item_type: std.ArrayList(u8),
    code: std.ArrayList(u8),
    equiv1: std.ArrayList(u8),
    equiv2: std.ArrayList(u8),
    equiv_types: std.StringHashMap(bool),
    inv_gfx: u32,

    normal: u8,
    magic: u8,
    rare: u8,

    pub fn deinit(self: *Self) void {
        self.item_type.deinit();
        self.code.deinit();
        self.equiv1.deinit();
        self.equiv2.deinit();
        self.equiv_types.deinit();
    }
};

pub fn getItemTypesTxt(allocator: std.mem.Allocator) !*std.ArrayList(ItemTypesTxt) {
    const itypes_txt = try std.fs.cwd().openFile(TxtNames.item_types, .{});
    defer itypes_txt.close();

    var parser = try zcsv.allocs.map.init(allocator, itypes_txt.reader(), .{ .column_delim = '\t' });
    defer parser.deinit();

    const itypes_array = try allocator.create(std.ArrayList(ItemTypesTxt));
    itypes_array.* = std.ArrayList(ItemTypesTxt).init(allocator);
    var itypes_index: u32 = 0;

    while (parser.next()) |row| {
        defer row.deinit();

        const item_type = row.data().get("ItemType") orelse return error.MissingType;
        const code = row.data().get("Code") orelse return error.MissingCode;
        const equiv1 = row.data().get("Equiv1") orelse return error.Missingequiv1;
        const equiv2 = row.data().get("Equiv2") orelse return error.Missingequiv2;
        var inv_gfx = try fieldToInt(u32, row.data().get("VarInvGfx") orelse return error.MissingVarInvGfx, 10);

        var normal = try fieldToInt(u8, row.data().get("Normal") orelse return error.MissingNormal, 10);
        var magic = try fieldToInt(u8, row.data().get("Magic") orelse return error.MissingMagic, 10);
        var rare = try fieldToInt(u8, row.data().get("Rare") orelse return error.MissingRare, 10);

        if (std.mem.eql(u8, fieldToStr(item_type).?.str, "Expansion") and
            fieldToStr(code) == null)
        {
            continue;
        }

        inv_gfx = if (inv_gfx != null) inv_gfx else 0;
        normal = if (normal != null) normal else 0;
        magic = if (magic != null) magic else 0;
        rare = if (rare != null) rare else 0;

        try itypes_array.append(ItemTypesTxt{
            .index = itypes_index,
            .item_type = try item_type.clone(allocator),
            .code = try code.clone(allocator),
            .equiv1 = try equiv1.clone(allocator),
            .equiv2 = try equiv2.clone(allocator),
            .equiv_types = std.StringHashMap(bool).init(allocator),
            .inv_gfx = inv_gfx.?,
            .normal = normal.?,
            .magic = magic.?,
            .rare = rare.?,
        });
        itypes_index += 1;
    }

    return itypes_array;
}

pub const WamTxt = struct {
    const Self = @This();

    index: u32,
    name: std.ArrayList(u8),
    wam_type: std.ArrayList(u8),
    code: std.ArrayList(u8),
    stackable: bool,
    quest: u8,
    questdiffcheck: u8,

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.wam_type.deinit();
        self.code.deinit();
    }
};

pub fn getWamTxt(allocator: std.mem.Allocator) !*std.ArrayList(WamTxt) {
    const weapons_txt = try std.fs.cwd().openFile(TxtNames.weapons, .{});
    defer weapons_txt.close();
    const armor_txt = try std.fs.cwd().openFile(TxtNames.armor, .{});
    defer armor_txt.close();
    const misc_txt = try std.fs.cwd().openFile(TxtNames.misc, .{});
    defer misc_txt.close();

    var weapons_parser = try zcsv.allocs.map.init(allocator, weapons_txt.reader(), .{ .column_delim = '\t' });
    defer weapons_parser.deinit();
    var armor_parser = try zcsv.allocs.map.init(allocator, armor_txt.reader(), .{ .column_delim = '\t' });
    defer armor_parser.deinit();
    var misc_parser = try zcsv.allocs.map.init(allocator, misc_txt.reader(), .{ .column_delim = '\t' });
    defer misc_parser.deinit();

    const wam_array = try allocator.create(std.ArrayList(WamTxt));
    wam_array.* = std.ArrayList(WamTxt).init(allocator);
    var wam_index: u32 = 0;

    var wam_parsers = [_]Parser(@TypeOf(weapons_txt.reader())){ weapons_parser, armor_parser, misc_parser };

    for (&wam_parsers) |*parser| {
        while (parser.next()) |row| {
            defer row.deinit();

            const name = row.data().get("name") orelse return error.MissingName;
            const wam_type = row.data().get("type") orelse return error.MissingType;
            const code = row.data().get("code") orelse return error.MissingCode;
            const stackable = try fieldToBool(row.data().get("stackable") orelse return error.MissingStackable);

            const quest = try fieldToInt(u8, row.data().get("quest") orelse return error.MissingQuest, 10);
            var questdiffcheck: ?u8 = undefined;

            if (@intFromPtr(parser) == @intFromPtr(&wam_parsers[1])) {
                questdiffcheck = null;
            } else {
                questdiffcheck = try fieldToInt(u8, row.data().get("questdiffcheck") orelse return error.MissingQuestDiffCheck, 10);
            }

            if (std.mem.eql(u8, fieldToStr(name).?.str, "Expansion") and
                fieldToStr(wam_type) == null)
            {
                continue;
            }

            try wam_array.append(WamTxt{
                .index = wam_index,
                .name = try name.clone(allocator),
                .wam_type = try wam_type.clone(allocator),
                .code = try code.clone(allocator),
                .stackable = if (stackable != null) stackable.? else false,
                .quest = if (quest != null) quest.? else 0,
                .questdiffcheck = if (questdiffcheck != null) questdiffcheck.? else 0,
            });
            wam_index += 1;
        }
    }

    return wam_array;
}

pub fn createItemTypeMap(allocator: std.mem.Allocator, itypes_array: *std.ArrayList(ItemTypesTxt)) !*std.StringHashMap(ItemTypesTxt) {
    const item_type_map = try allocator.create(std.StringHashMap(ItemTypesTxt));
    item_type_map.* = std.StringHashMap(ItemTypesTxt).init(allocator);

    var equiv1_map = std.StringHashMap([]u8).init(allocator);
    var equiv2_map = std.StringHashMap([]u8).init(allocator);
    defer equiv1_map.deinit();
    defer equiv2_map.deinit();

    for (itypes_array.items) |*itype| {
        if (!std.mem.eql(u8, @as([]u8, itype.equiv1.items), "")) {
            try equiv1_map.put(@as([]u8, itype.code.items), @as([]u8, itype.equiv1.items));
        }

        if (!std.mem.eql(u8, @as([]u8, itype.equiv2.items), "")) {
            try equiv2_map.put(@as([]u8, itype.code.items), @as([]u8, itype.equiv2.items));
        }
    }

    for (itypes_array.items) |*itype| {
        const item_code: []u8 = @as([]u8, itype.code.items);

        if (!std.mem.eql(u8, item_code, "")) {
            try findAllEquivalentTypes(item_code, &itype.equiv_types, &equiv1_map, &equiv2_map);
            try item_type_map.put(item_code, itype.*);
        }
    }

    return item_type_map;
}

pub fn createItemCodeMap(allocator: std.mem.Allocator, wam_list: *std.ArrayList(WamTxt)) !*std.StringHashMap(WamTxt) {
    const item_code_map = try allocator.create(std.StringHashMap(WamTxt));
    item_code_map.* = std.StringHashMap(WamTxt).init(allocator);

    for (wam_list.items) |*wam| {
        try item_code_map.put(@as([]u8, wam.code.items), wam.*);
    }

    return item_code_map;
}

pub const TxtFileSizes = struct {
    item_stat_cost: usize,
    item_types: usize,
    weapons: usize,
    armor: usize,
    misc: usize,
    wam: usize,
};

pub fn getFileSizes(allocator: std.mem.Allocator) !*TxtFileSizes {
    var file_sizes: *TxtFileSizes = try allocator.create(TxtFileSizes);

    file_sizes.item_stat_cost = try helper.csvLineCount(allocator, TxtNames.item_stat_cost);
    file_sizes.item_types = try helper.csvLineCount(allocator, TxtNames.item_types);

    file_sizes.weapons = try helper.csvLineCount(allocator, TxtNames.weapons);
    file_sizes.armor = try helper.csvLineCount(allocator, TxtNames.armor);
    file_sizes.misc = try helper.csvLineCount(allocator, TxtNames.misc);
    file_sizes.wam = file_sizes.weapons + file_sizes.armor + file_sizes.misc;

    return file_sizes;
}

pub const States = enum(u16) {
    const Self = @This();

    pub const set_states = [5]u16{
        @intFromEnum(Self.itemset1),
        @intFromEnum(Self.itemset2),
        @intFromEnum(Self.itemset3),
        @intFromEnum(Self.itemset4),
        @intFromEnum(Self.itemset5),
    };

    none = 0,
    freeze = 1,
    itemset1 = 165,
    itemset2 = 166,
    itemset3 = 167,
    itemset4 = 168,
    itemset5 = 169,
    itemset6 = 170,
    runeword = 171,
};
