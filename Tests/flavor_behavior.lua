local function load(path,AF) assert(loadfile(path))("ArtisanFinder",AF) end
local function frame()
    return {SetPoint=function(self,...) self.point={...} end,ClearAllPoints=function() end}
end
ProfessionsFrame={CloseButton={}}
for _,flavor in ipairs({"Retail","Forever"}) do
    local AF={}
    load("Flavors/"..flavor..".lua",AF)
    assert(AF.CHANNEL_NAME=="ArtisanFinder","both flavors share the ArtisanFinder discovery channel")
    load("Core/Bootstrap.lua",AF)
    load("Core/Slash.lua",AF)
    local notified=false
    AF.Text=function(_,key) return key end AF.Print=function() end
    AF.DevNotifyOrder=function() notified=true end AF.GetPlayerFullName=function() return "Tester-Realm" end
    AF:HandleDevSlash("notify")
    assert(notified==AF.IsRetail,"Order notification commands only exist on Retail")
    load("Features/Crafter/UI.lua",AF)
    if AF.IsRetail then load("Features/Retail/Crafter/ReagentControls.lua",AF) end
    if AF.IsForever then load("Features/Forever/CrafterBehavior.lua",AF) end
    AF.GetCraftingSchematicForm=function() return {} end
    AF.crafterFrame=frame() AF.crafterDefaultsFrame=frame()
    AF:PositionCrafterUI()
    local point=AF.crafterDefaultsFrame.point
    if AF.IsForever then
        assert(point[1]=="TOPLEFT" and point[3]=="TOPRIGHT" and point[4]==62 and point[5]==0,"Forever sidebar stays aligned and clears native profession tabs")
        assert(AF.PREFIX=="ARTFINDFF1" and AF.PROTOCOL_VERSION=="FF1","Forever messaging isolation")
        assert(not AF:IsUnlimitedReagentsEnabled(),"Forever never mutates Retail reagent ownership")
    else
        assert(point[1]=="BOTTOMLEFT" and point[3]=="BOTTOMRIGHT" and point[5]==24,"Retail original sidebar placement")
        assert(AF.PREFIX=="ARTFIND1" and AF.PROTOCOL_VERSION=="5","Retail messaging unchanged")
        AF.db={unlimitedReagents=true}
        assert(AF:IsUnlimitedReagentsEnabled(),"Retail reagent behavior retained")
    end
end
print("PASS shared crafter UI with separate Retail/Forever placement, reagent behavior and protocols")
