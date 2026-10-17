local AF={db={artisanProfile={items={}},customerCache={}},playerName="Player Name",CACHE_MAX_AGE=1209600}
assert(loadfile("Features/Forever/GuildDirectory.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/DiscoverySources.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Directory.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Hierarchy.lua"))("ArtisanFinder",AF)
AF.NormalizeName=function(_,name) return name end
AF.Now=function() return 1000 end
AF.GetDisplayItemName=function(_,id) return "Item "..id end
AF.GetPlayerFullName=function() return AF.playerName end
AF.IsFavoriteArtisan=function() return false end
AF.ForEachArtisanProfile=function(_,callback) callback(AF.playerName,AF.db.artisanProfile) end
local ownLookups=0
AF.GetOwnAltRows=function(_,itemID)
    ownLookups=ownLookups+1
    return {{name=AF.playerName,professionID=164,itemID=itemID}}
end
AF.CustomerEntryMatchesFilter=function() return false end
IsInGuild=function() return false end
for id=1,20000 do AF.db.artisanProfile.items[id]={professionID=164,itemName="Item "..id} end
local rows=AF:GetDirectoryEntries("")
assert(#rows==1 and ownLookups==1,"collapsed discovery must not perform one own-alt lookup per known craft")
for id=1,1000 do
    AF.db.customerCache[id]={{name="Crafter "..id,professionID=164,itemName="Item "..id}}
end
local originalPairs=pairs
local scans=0
pairs=function(value)
    if value==AF.db.customerCache then scans=scans+1 end
    return originalPairs(value)
end
local build={}
for id=1,1000 do
    local crafts=AF:GetForeverKnownCrafts("Crafter "..id,164,build)
    assert(#crafts==1 and crafts[1].itemID==id,"indexed lookup retains the correct crafter's recipe")
end
pairs=originalPairs
assert(scans==1,"all craft lookups in one rebuild share one cache traversal")
AF.db.customerCache[1001]={{name="Crafter 1",professionID=164,itemName="New recipe"}}
assert(#AF:GetForeverKnownCrafts("Crafter 1",164)==2,"later lookups cannot reuse a stale build index")
print("PASS discovery 20000-item collapsed listing uses one lookup; 1000 craft lookups share one cache scan")
