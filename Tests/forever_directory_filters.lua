local AF={db={customerCache={},artisanProfile={}},playerName="Self Smith"}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Flavors/Forever.lua") load("Features/Forever/Names.lua") load("Features/Forever/GuildDirectory.lua") load("Features/Forever/DiscoverySources.lua") load("Features/Forever/Directory.lua")
AF.GetProfessionName=function(_,id) return ({[333]="Enchanting",[164]="Blacksmithing",[165]="Leatherworking"})[id] or tostring(id) end
AF.Now=function() return 1000 end
AF.IsFavoriteArtisan=function() return false end
AF.GetDisplayItemName=function(_,id) return id==100 and "Mithril Sword" or "Mithril Shield" end
AF.CustomerEntryMatchesFilter=function(_,entry,query) return entry.name:lower():find(query,1,true) end
AF.ForEachArtisanProfile=function() end
AF.GetCachedArtisans=function() return {} end
AF.Text=function(_,key) return key end
AF.RefreshCustomerQuery=function(_,force) AF.queried=force and AF.currentCustomerItemID or nil end
local function offer(name,profession,updated)
 return {name=name,target=name,professionID=profession,itemID=100,updatedAt=updated}
end
AF.db.customerCache={
 ["100"]={one=offer("Fess Oakenshield",164,990),two=offer("Fess Stormcaller",164,980)},
 ["101"]={one=offer("Fess Oakenshield",333,995)},
}
AF.tradeLeads={one={name="Fess Oakenshield",target="Fess Oakenshield",professionCandidates={[165]=true},updatedAt=999}}
local rows=AF:GetForeverDirectoryRows("")
assert(#rows==2,"one row per full unique name, not first name or profession")
local fess=rows[1]
assert(fess.name=="Fess Oakenshield" and fess.professions[164] and fess.professions[333] and fess.professions[165])
assert(fess.source=="ADDON" and fess.sources.TRADE,"source precedence retains both observations")
assert(#AF:GetForeverDirectoryRows("stormcaller")==1,"surname search")
rows=AF:GetForeverDirectoryRows("",333)
assert(#rows==1 and rows[1].name=="Fess Oakenshield" and rows[1].professions[333],"profession header filter")
rows=AF:GetForeverDirectoryRows("",nil,"TRADE")
assert(#rows==1 and rows[1].source=="TRADE" and rows[1].professions[165],"source header filter")
assert(#AF:GetForeverDirectoryRows("",333,"TRADE")==0,"profession/source filters combine")
AF.db.tradeLeadCache={old={name="Ash Copperhand",target="Ash Copperhand",professionCandidates={[164]=true},updatedAt=10}}
assert(#AF:GetForeverDirectoryRows("",nil,"TRADE")==2,"expired live trade offers remain in discovery history")
AF.db.tradeLeadCache=nil
AF.ForEachArtisanProfile=function(_,callback)
 callback("Other Smith",{items={["100"]={itemName="Mithril Sword"},["101"]={itemName="Mithril Shield"}}})
end
local id,matches=AF:SelectCustomerItem("mithril")
assert(id==nil and #matches==2,"ambiguous item names offer choices")
assert(AF:SelectCustomerItem("mithril sword")==100 and AF.queried==100,"exact item-name query")
AF:SelectCustomerItem("unknown item")
assert(AF.currentCustomerItemID==100,"invalid input cannot silently clear selected item")
assert(AF:SelectCustomerItem("|Hitem:101:0|h[Mithril Shield]|h")==101,"item links resolve IDs")
AF:SelectCustomerItem(nil)
assert(AF.currentCustomerItemID==nil,"clear returns to all artisans")
print("PASS grouped discovery history, full-name uniqueness, combined header filters and item name/link ambiguity")

AF.currentCustomerItemID=nil
AF.db.artisanContacts={
 ["Alt Surname"]={target="Fess Oakenshield"},
 ["Second Alt"]={target="Alt Surname"},
 ["Unrelated Alt"]={target="Fess Stormcaller"},
}
local matches=AF:GetForeverArtisanNameMatches("second alt")
assert(matches["Fess Oakenshield"] and matches["Alt Surname"] and not matches["Fess Stormcaller"],"alt-name search follows known relationships only")
local found=AF:GetForeverDirectoryRows("second alt")
assert(#found==1 and found[1].name=="Fess Oakenshield","searching an alt finds its artisan")
AF.db.artisanContacts=nil
AF.db.customerCache[100]={alt={name="Cached Alt",orderTarget="Cached Alt",target="Fess Oakenshield",professionID=333,updatedAt=999}}
assert(AF:GetForeverArtisanNameMatches("cached alt")["Fess Oakenshield"],"cached contact relationships participate in alt searches")
print("PASS known alt-name searches resolve associated artisan without conflating unrelated characters")
