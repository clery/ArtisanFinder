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
assert(migrated.rowColor == "abcdefff", "legacy RGB row color should normalize as opaque RGBA")
assert(migrated.iconColor == "123456ff", "legacy RGB icon color should normalize as opaque RGBA")
assert(AF:NormalizeShopColor("#12345678") == "12345678", "RGBA color should preserve alpha")
local _, _, _, transparentAlpha = AF:GetShopColorRGBA("12345600")
assert(transparentAlpha == 0, "RGBA color alpha should be readable")
assert(migrated.emblemStyle == nil, "cosmetics without an emblem should remain emblem-free")
assert(migrated.rowTextureStyle == nil, "cosmetics without a texture should use the default customer row")

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
assert(#emblemOptions == 193, "emblem picker should include none and omit the unused atlas tail")
assert(emblemOptions[1] == "" and emblemOptions[2] == 0 and emblemOptions[#emblemOptions] == 191, "emblem picker should expose none before the populated contiguous range")
assert(AF:GetShopTabardEmblemPickerMaxStyle() == 191, "emblem picker max should stay below the legacy saved-value max")
assert(AF:NormalizeShopTabardEmblemStyle("255", nil) == 255, "legacy saved emblem styles should still normalize")

local left, right, top, bottom = AF:GetShopTabardEmblemTexCoords(17)
assert(left == 1 / 16 and right == 2 / 16 and top == 1 / 16 and bottom == 2 / 16, "emblem texcoords should use the Blizzard 16x16 large guild sheet")

local textureOptions = AF:GetShopRowTextureOptions()
assert(#textureOptions == 11, "row texture options should include the default customer row")
assert(textureOptions[1].value == "" and textureOptions[1].key == "default", "first row texture option should represent no cosmetic overlay")
for index = 2, #textureOptions do
	assert(textureOptions[index].value == index - 1, "custom row texture option values should start at one and have no holes")
end
assert(textureOptions[2].key == "parchment" and textureOptions[11].key == "tooltip", "row texture options should expose the full contiguous range")
assert(textureOptions[4].tileWidth == 32 and textureOptions[4].tileHeight == 32, "repeatable row textures should expose tile sizing metadata")
assert(textureOptions[5].hTile == nil, "quest row texture should stretch as a single gradient")
assert(textureOptions[6].key == "marble" and textureOptions[8].key == "blackmarket", "additional row textures should be exposed in order")
assert(textureOptions[6].hTile == true and textureOptions[8].vTile == true, "additional row textures should tile safely")
assert(textureOptions[9].key == "dialog" and textureOptions[11].key == "tooltip", "dialog row textures should be exposed in order")
assert(textureOptions[9].tileWidth == 32 and textureOptions[11].tileHeight == 32, "dialog row textures should use backdrop tile sizing")
assert(AF:GetShopRowTextureStyle(nil) == nil, "default customer row should not resolve to a cosmetic texture")

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
