local AF = {}
local LoadFile = rawget(_G, "loadfile")

local function Check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function LoadAddonFile(path)
	local chunk, err = LoadFile(path)
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

LoadAddonFile("Core/Bootstrap.lua")
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

-- Large Forever guilds must not scan all cached members/recipes per roster row.
AF.IsForever=true
AF.NormalizeName=function(_,name) return name end
AF:EnsureGuildCache()
AF.guildRosterByName={}
AF.guildProfessionMembers={}
AF.guildRecipeMembers={}
AF.guildCache.rosterByName=AF.guildRosterByName
AF.guildCache.professionMembers=AF.guildProfessionMembers
AF.guildCache.recipeMembers=AF.guildRecipeMembers
roster={}
for index=1,1000 do
    local name="Member "..index
    roster[index]={name=name,online=true,guid="Player-"..index}
    AF.guildRosterByName[name]={name=name,guid="Player-"..index}
    AF.guildRecipeMembers[index]={members={name},online={[name]=false}}
end
local originalPairs=pairs
local traversals=0
pairs=function(value)
    if value==AF.guildRosterByName or value==AF.guildRecipeMembers then traversals=traversals+1 end
    return originalPairs(value)
end
AF:RefreshGuildRosterCache(false)
pairs=originalPairs
Check(traversals<12,"large guild refresh must use a constant number of full cache traversals")
Check(AF.guildRecipeMembers[1000].online["Member 1000"],"linear pass still updates cached recipe availability")
local pending={}
C_Timer={After=function(delay,callback) pending[#pending+1]={delay=delay,callback=callback} end}
local reads=0
local originalInfo=GetGuildRosterInfo
GetGuildRosterInfo=function(index) reads=reads+1 return originalInfo(index) end
for index=1,1000 do AF:ResolveGuildMemberName("Unknown "..index,true) end
Check(reads==0 and #pending==0,"nonguild crafters must not request fresh roster data once a snapshot exists")
AF.foreverGuildRosterReadyKey=nil
for index=1,1000 do AF:ResolveGuildMemberName("Unknown "..index,true) end
Check(reads==0 and #pending==1,"initial unknown lookups batch into one roster request")
pending[1].callback()
Check(reads==1000,"batched refresh reads each roster member once")
AF:QueueGuildRosterCacheRefresh(false)
Check(pending[2].delay>=5,"Forever guild event bursts are limited to one rebuild per five seconds")
print("PASS large Forever guild linear cache traversal, deferred unknown-name lookups and event throttling")

-- A completed roster refresh must not schedule another through a discovery lookup.
pending={}
AF.guildRosterRefreshQueued=nil
AF.RefreshCustomerResults=function() AF:ResolveGuildMemberName("Nonguild Crafter",true) end
AF.QueueCustomerResultsRefresh=nil
AF:QueueGuildRosterCacheRefresh(false)
pending[1].callback()
Check(#pending==1,"roster -> discovery -> nonguild lookup cannot perpetuate its own timer")
local recipeScans=0
pairs=function(value)
    if value==AF.guildRecipeMembers then recipeScans=recipeScans+1 end
    return originalPairs(value)
end
local _,changed=AF:RefreshGuildRosterCache(false)
pairs=originalPairs
Check(changed==false and recipeScans==0,"unchanged Forever roster skips all recipe cache propagation and reconciliation")
roster[1].online=false
local _,updated=AF:RefreshGuildRosterCache(false)
Check(updated and not AF.guildRecipeMembers[1].online["Member 1"],"real roster status changes still propagate")
print("PASS nonguild lookup feedback loop stops; unchanged roster skips recipe work and real changes propagate")
