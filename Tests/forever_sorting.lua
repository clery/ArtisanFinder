local AF={db={}}
assert(loadfile("Features/Forever/DiscoverySources.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Sorting.lua"))("ArtisanFinder",AF)
AF.IsFavoriteArtisan=function(_,entry) return entry and entry.favorite or false end
AF.Text=function(_,key) return key=="FOREVER_SOURCE_TRADE" and "Trade offer" or key end
AF.GetForeverDirectoryPrice=function(_,row) return "",{},row.amount end
AF.RefreshCustomerResults=function(self) self.refreshed=true end
local function rows()
    return {{name="Zed Smith",amount=100,updatedAt=300,source="TRADE"},
        {name="Amy Weaver",amount=10000,updatedAt=100,source="ADDON"},
        {name="Ben Enchanter",amount=nil,updatedAt=200,source="LINKEDINN"},
        {name="Cara Cook",amount=0,updatedAt=200,source="ADDON"}}
end
local list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Amy Weaver" and list[4].name=="Zed Smith","default name sort is ascending")
AF:SetForeverDirectorySort("name") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Zed Smith" and list[4].name=="Amy Weaver","repeated label click reverses direction")
AF:SetForeverDirectorySort("price") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Cara Cook" and list[2].name=="Zed Smith" and list[4].name=="Ben Enchanter","prices sort numerically with free first and unknown last")
AF:SetForeverDirectorySort("price") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Amy Weaver" and list[3].name=="Cara Cook" and list[4].name=="Ben Enchanter","unknown remains last when expensive first")
AF:SetForeverDirectorySort("observed") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Zed Smith" and list[4].name=="Amy Weaver","last observed defaults to newest first")
AF:SetForeverDirectorySort("observed") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Amy Weaver" and list[4].name=="Zed Smith")
AF:SetForeverDirectorySort("source") list=rows() AF:SortForeverDirectoryRows(list)
assert(list[1].name=="Amy Weaver" and list[2].name=="Cara Cook" and list[3].name=="Ben Enchanter" and list[4].name=="Zed Smith","source sorts by displayed source name, ties by artisan")
local persisted=AF.db.foreverDirectorySort
AF.directoryPage=7 AF:SetForeverDirectorySort("source")
assert(AF.directoryPage==1 and AF.refreshed and AF.db.foreverDirectorySort.descending)
local other={db=AF.db} assert(loadfile("Features/Forever/DiscoverySources.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Sorting.lua"))("ArtisanFinder",other)
local key,descending=other:GetForeverDirectorySort()
assert(key=="source" and descending,"sort survives reload")
AF:SetForeverDirectorySort("invalid")
assert(AF.db.foreverDirectorySort.key=="source","invalid columns ignored")
print("PASS discovery sort directions, numeric prices, unknown-last, source labels, timestamps and persistence")

for _,column in ipairs({"name","source","price","observed"}) do
    for _,reverse in ipairs({false,true}) do
        AF.db.foreverDirectorySort={key=column,descending=reverse}
        local expected=rows()
        AF:SortForeverDirectoryRows(expected)
        local list=rows()
        for _,row in ipairs(list) do row.entry={favorite=row.name=="Zed Smith" or row.name=="Ben Enchanter"} end
        AF:SortForeverDirectoryRows(list)
        local ordered={}
        for _,favorite in ipairs({true,false}) do
            for _,row in ipairs(expected) do
                if (row.name=="Zed Smith" or row.name=="Ben Enchanter")==favorite then ordered[#ordered+1]=row.name end
            end
        end
        for index,row in ipairs(list) do assert(row.name==ordered[index],column..": favorites first, selected order preserved within each group") end
    end
end
print("PASS favorites precede other artisans for every sort column and direction")

AF.directoryLiveOrder=nil
AF.db.foreverDirectorySort={key="observed",descending=true}
local initial=rows() AF:SortForeverDirectoryRows(initial)
AF:StabilizeForeverDirectoryRows(initial,"open")
local expected={} for index,row in ipairs(initial) do expected[index]=row.name end
local live=rows() live[2].updatedAt=9999
live[#live+1]={name="Aaron New",updatedAt=10000,source="ADDON",amount=1}
AF:SortForeverDirectoryRows(live) AF:StabilizeForeverDirectoryRows(live,"open")
for index,name in ipairs(expected) do assert(live[index].name==name,"presence updates do not reorder open discovery") end
assert(live[5].name=="Aaron New","newly detected artisan appends after existing artisans")
AF:SortForeverDirectoryRows(live) AF:StabilizeForeverDirectoryRows(live,"changed sort")
assert(live[1].name=="Aaron New","explicit sort/filter changes apply the selected order")
live[5].entry={favorite=true}
AF:StabilizeForeverDirectoryRows(live,"changed sort")
assert(live[1].entry.favorite,"favorites remain first during stable discovery")
print("PASS live discovery preserves existing crafter positions, appends new crafters and respects explicit sorting/favorites")
