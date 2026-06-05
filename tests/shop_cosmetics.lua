local AF = {
	MAX_SHOP_NAME_BYTES = 128,
	MAX_SHOP_TABARD_EMBLEM_STYLE = 255,
	MAX_SHOP_ROW_TEXTURE_STYLE = 10,
	SCHEMA_VERSION = 19,
}

assert(loadfile("Utils/Formatting.lua"))("ArtisanFinder", AF)
assert(loadfile("Core/Data.lua"))("ArtisanFinder", AF)

local migrated = AF:NormalizeShopCosmetics({
	shopName = " Test | Shop ",
	rowColor = "ABCDEF",
	iconColor = "#123456",
})

assert(migrated.shopName == "Test Shop", "shop name should strip pipes, trim, and collapse spaces")
assert(migrated.rowColor == "abcdef", "row color should normalize")
assert(migrated.iconColor == "123456", "icon color should normalize")
assert(migrated.emblemStyle == 0, "legacy cosmetics should gain default emblem style")
assert(migrated.rowTextureStyle == 1, "legacy cosmetics should gain default row texture style")

local selected = AF:NormalizeShopCosmetics({
	emblemStyle = "255",
	rowTextureStyle = "10",
})

assert(selected.emblemStyle == 255, "emblem style upper bound should be accepted")
assert(selected.rowTextureStyle == 10, "row texture upper bound should be accepted")
assert(AF:NormalizeShopCosmetics({ rowTextureStyle = "1" }).rowTextureStyle == 1, "first row texture style should be accepted")
assert(AF:NormalizeShopCosmetics({ emblemStyle = "999" }) == nil, "invalid style-only cosmetics should be dropped")
assert(AF:NormalizeShopCosmetics({ rowTextureStyle = "99" }) == nil, "invalid row texture-only cosmetics should be dropped")

local emblemOptions = AF:GetShopTabardEmblemOptions()
assert(#emblemOptions == 192, "emblem picker should omit the unused atlas tail")
assert(emblemOptions[1] == 0 and emblemOptions[#emblemOptions] == 191, "emblem picker should expose the populated contiguous range")
assert(AF:GetShopTabardEmblemPickerMaxStyle() == 191, "emblem picker max should stay below the legacy saved-value max")
assert(AF:NormalizeShopTabardEmblemStyle("255", nil) == 255, "legacy saved emblem styles should still normalize")

local left, right, top, bottom = AF:GetShopTabardEmblemTexCoords(17)
assert(left == 1 / 16 and right == 2 / 16 and top == 1 / 16 and bottom == 2 / 16, "emblem texcoords should use the Blizzard 16x16 large guild sheet")

local textureOptions = AF:GetShopRowTextureOptions()
assert(#textureOptions == 10, "row texture options should be contiguous")
for index, option in ipairs(textureOptions) do
	assert(option.value == index, "row texture option values should start at one and have no holes")
end
assert(textureOptions[1].key == "parchment" and textureOptions[10].key == "tooltip", "row texture options should expose the full contiguous range")
assert(textureOptions[3].tileWidth == 32 and textureOptions[3].tileHeight == 32, "repeatable row textures should expose tile sizing metadata")
assert(textureOptions[4].hTile == nil, "quest row texture should stretch as a single gradient")
assert(textureOptions[5].key == "marble" and textureOptions[7].key == "blackmarket", "additional row textures should be exposed in order")
assert(textureOptions[5].hTile == true and textureOptions[7].vTile == true, "additional row textures should tile safely")
assert(textureOptions[8].key == "dialog" and textureOptions[10].key == "tooltip", "dialog row textures should be exposed in order")
assert(textureOptions[8].tileWidth == 32 and textureOptions[10].tileHeight == 32, "dialog row textures should use backdrop tile sizing")

local db = {
	schemaVersion = 18,
	artisanProfile = { shopCosmetics = { rowTextureStyle = 11 } },
	artisanCharacters = {
		Crafter = { shopCosmetics = { rowTextureStyle = 2 } },
	},
	customerCache = {
		["123"] = {
			Crafter = { shopCosmetics = { rowTextureStyle = 5 } },
		},
	},
}
AF:MigrateDB(db)
assert(db.schemaVersion == 19, "shop texture migration should update schema version")
assert(db.artisanProfile.shopCosmetics.rowTextureStyle == 10, "legacy tooltip texture should migrate to contiguous value")
assert(db.artisanCharacters.Crafter.shopCosmetics.rowTextureStyle == 1, "legacy parchment texture should migrate to contiguous value")
assert(db.customerCache["123"].Crafter.shopCosmetics.rowTextureStyle == 4, "legacy cached texture should migrate to contiguous value")

AF.GetDisplayPlayerName = function(_, name)
	return name
end
local displayName = AF:GetShopDisplayName({ name = "Crafter", shopCosmetics = { shopName = "Fine Wares" } })
assert(displayName == "Fine Wares - Crafter", "shop display name should use dash separator")

print("shop_cosmetics: ok")
