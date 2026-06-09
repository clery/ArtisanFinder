local AF = {}

local function Check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function LoadAddonFile(path)
	local chunk, err = loadfile(path)
	Check(chunk, err)
	return chunk("ArtisanFinder", AF)
end

local roster = {}
local rosterRequests = 0

time = function()
	return 1000
end

GetRealmName = function()
	return "Realm"
end

GetNormalizedRealmName = function()
	return "Realm"
end

IsInGuild = function()
	return true
end

GetGuildInfo = function()
	return "Test Guild", nil, nil, "Realm"
end

SetGuildRosterShowOffline = function()
end

C_GuildInfo = {
	GuildRoster = function()
		rosterRequests = rosterRequests + 1
	end,
}

GetNumGuildMembers = function()
	return #roster
end

GetGuildRosterInfo = function(index)
	local member = roster[index]
	if not member then
		return nil
	end
	return member.name, nil, nil, nil, nil, nil, nil, nil, member.online, nil, nil, nil, nil, member.isMobile, nil, nil, member.guid
end

AF.GetBaseProfessionID = function(_, professionID)
	return tonumber(professionID)
end

AF.NormalizeName = function(_, name)
	if not name or name == "" then
		return nil
	end
	name = tostring(name):gsub("%s+", "")
	if not name:find("-", 1, true) then
		name = name .. "-Realm"
	end
	return name
end

AF.Now = function()
	return time()
end

AF.DebugLog = function()
end

AF.IsNameOnConnectedRealm = function()
	return true
end

AF.db = {
	guildCache = {
		byGuild = {},
	},
	customerCache = {},
	artisanContacts = {},
}

LoadAddonFile("Features/Social/Guild.lua")

AF:EnsureGuildCache()
AF.guildRosterByName["Alpha-Realm"] = {
	name = "Alpha-Realm",
	online = true,
	guid = "Player-1",
	updatedAt = 900,
}
AF.guildRosterByName["Beta-Realm"] = {
	name = "Beta-Realm",
	online = true,
	guid = "Player-2",
	updatedAt = 900,
}
AF.guildProfessionMembers["164"] = {
	professionID = 164,
	members = {
		["Alpha-Realm"] = {
			name = "Alpha-Realm",
			guid = "Player-1",
			online = true,
		},
		["Beta-Realm"] = {
			name = "Beta-Realm",
			guid = "Player-2",
			online = true,
		},
	},
}
AF.guildRosterCount = 2
AF:RebuildGuildRosterNameLookup()

roster = {
	{ name = "Alpha-Realm", online = true, guid = "Player-1" },
}

local requestedCount = AF:RefreshGuildRosterCache(true)
Check(requestedCount == 1, "requested refresh should parse visible roster rows")
Check(rosterRequests == 1, "requested refresh should ask Blizzard for fresh roster data")
Check(AF.guildRosterByName["Beta-Realm"], "requested refresh should not prune cached roster member from partial data")
Check(AF.guildProfessionMembers["164"].members["Beta-Realm"], "requested refresh should not prune cached profession member from partial data")
Check(AF:ResolveGuildMemberName("Beta", false) == "Beta-Realm", "requested refresh should preserve short-name lookup for cached member")

AF:RefreshGuildRosterCache(false)
Check(not AF.guildRosterByName["Beta-Realm"], "authoritative refresh should prune departed roster member")
Check(not AF.guildProfessionMembers["164"].members["Beta-Realm"], "authoritative refresh should prune departed profession member")

roster = {
	{ name = "Gamma", online = true, guid = "Player-3" },
}

AF:RefreshGuildRosterCache(false)
Check(AF.guildRosterByName["Gamma-Realm"], "short roster row should initially use local normalized key")

local gammaMember = AF:RememberGuildProfessionMember(164, "Gamma-OtherRealm", "Blacksmithing", true, 100, true)
Check(gammaMember, "full connected-realm profession member should match short roster row")
Check(AF.guildRosterByName["Gamma-OtherRealm"], "full connected-realm name should promote short roster cache key")
Check(not AF.guildRosterByName["Gamma-Realm"], "promoted connected-realm member should not remain under local fallback key")
Check(AF.guildProfessionMembers["164"].members["Gamma-OtherRealm"], "profession member should be stored under full connected-realm key")

roster = {
	{ name = "Gamma", online = false, guid = "Player-3" },
}

AF:RefreshGuildRosterCache(false)
Check(AF.guildRosterByName["Gamma-OtherRealm"], "short follow-up roster refresh should preserve known full connected-realm key")
Check(AF.guildRosterByName["Gamma-OtherRealm"].online == false, "preserved connected-realm roster entry should still update online status")
Check(AF:ResolveGuildMemberName("Gamma", false) == "Gamma-OtherRealm", "short lookup should not demote known connected-realm key to local fallback")
Check(AF:ResolveGuildMemberName("Gamma-Realm", false) == "Gamma-OtherRealm", "explicit local fallback should not demote known connected-realm key")

roster = {
	{ name = "Delta", online = true, guid = "Player-4" },
}

AF.guildRosterByName["Delta-OtherRealm"] = {
	name = "Delta-OtherRealm",
	online = true,
	guid = "Player-4",
	updatedAt = 900,
}
AF:RebuildGuildRosterNameLookup()
AF:RefreshGuildRosterCache(false)
Check(AF.guildRosterByName["Delta-OtherRealm"], "authoritative short roster should not prune cached connected-realm member with matching GUID")
Check(not AF.guildRosterByName["Delta-Realm"], "cached remote connected-realm key should win over local fallback for same GUID")

print("guild roster cache tests: PASS")
