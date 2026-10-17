local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
GetLocale=function() return "enUS" end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
load("Utils/Formatting.lua") load("Features/Forever/Pricing.lua") load("Features/Forever/Hierarchy.lua")
AF.playerName="Self Crafter"
AF.NormalizeName=function(_,name) return name end
AF.GetPlayerFullName=function() return AF.playerName end
AF.GetProfessionPriceEntry=function(_,profile,id) return profile.professionPrices and profile.professionPrices[tostring(id)] end
AF.GetDisplayItemName=function(_,id) return "Item "..id end
AF.GetRecipeOutputItemIDs=function(_,id) return {[id+1000]=true} end
AF.GetProfessionName=function(_,id) return "Profession "..id end
AF.IsSecretValue=function() return false end
AF.CanReliablyOpenProfession=function(_,entry) return entry.professionLink~=nil end
AF.RefreshCustomerResults=function(self) self.refreshed=true end
local profession={name="Remote Crafter",professionID=333,priceCopper=50000,commissionSpecified=true,itemID=2000,recipeID=1000}
local other={name="Remote Crafter",professionID=165}
AF.db={artisanProfile={items={},professions={}},customerCache={
    [2000]={one=profession},[2001]={one={name="Remote Crafter",professionID=333,recipeID=1001}}},
    linkedInnDiscoveries={["Remote Crafter"]={updatedAt=1000,professions={[333]={recipes={1000,1002}}}}},
    foreverDiscoveries={["Remote Crafter"]={commissions={[333]={priceCopper=10000,commissionSpecified=true,note="Bring your own materials."}}}}}
local group={name="Remote Crafter",entry=profession,offers={profession,other},professions={[333]=true,[165]=true},source="ADDON",updatedAt=1000}
local rows=AF:BuildForeverExpandedRows({group},1,1)
assert(#rows==1 and rows[1].kind=="artisan")
AF:ToggleForeverDirectoryRow(rows[1])
rows=AF:BuildForeverExpandedRows({group},1,1)
assert(#rows==3 and rows[2].kind=="profession" and rows[2].professionID==165 and rows[3].professionID==333)
AF.currentCustomerItemID=2000
assert(AF:GetForeverDirectoryPrice(rows[3].group,false)==AF:FormatMoney(10000),"job uses default even during item search")
assert(AF:GetEntryNote(AF:GetForeverProfessionDefaults(group.name,333))=="Bring your own materials.")
AF.currentCustomerItemID=nil
AF:ToggleForeverDirectoryRow(rows[3])
rows=AF:BuildForeverExpandedRows({group},1,1)
assert(#rows==6 and rows[4].kind=="craft" and rows[5].kind=="craft" and rows[6].kind=="craft","cache and Linked Inn crafts combine without duplicates")
assert(AF:GetForeverDirectoryPrice(rows[4].group,rows[4].group.entry.itemID)==AF:FormatMoney(50000),"craft item quote overrides job default")
AF:ToggleForeverDirectoryRow(rows[2])
rows=AF:BuildForeverExpandedRows({group},1,1)
assert(rows[3].kind=="empty","unknown recipes show empty state rather than fabricated crafts")
AF:ToggleForeverDirectoryRow(rows[1])
assert(#AF:BuildForeverExpandedRows({group},1,1)==1,"parent collapse hides descendants")
AF:ToggleForeverDirectoryRow(AF:BuildForeverExpandedRows({group},1,1)[1])
assert(#AF:BuildForeverExpandedRows({group},1,1)==7,"reopening preserves profession expansion state")
assert(#AF:BuildForeverExpandedRows({group,group},2,2)==7,"pagination applies to artisans before expansion")
local filtered=AF:BuildForeverExpandedRows({group},1,1,"item 2001")
assert(#filtered==3 and filtered[3].group.entry.itemID==2001,"item search hides unrelated crafts and professions")
assert(#AF:BuildForeverExpandedRows({group},1,1,"remote crafter")==7,"artisan search preserves all crafts")
assert(#AF:BuildForeverExpandedRows({group},1,1,"profession 333")==5,"profession search preserves its crafts only")
AF.currentCustomerItemID=2000
filtered=AF:BuildForeverExpandedRows({group},1,1)
assert(#filtered==3 and filtered[3].group.entry.itemID==2000,"selected item filters crafts by exact ID")
AF.currentCustomerItemID=nil
assert(#AF:BuildForeverExpandedRows({group},1,1)==7,"clearing search restores crafts and expansion state")
print("PASS expandable discovery hierarchy, recipe deduplication, default commission/note, item overrides and collapse state")

local savedDB=AF.db
AF.db={artisanCharacters={Alt={professions={["164"]={skillLevel=225,maxSkillLevel=300}}}},
    foreverDiscoveries={Remote={skills={[164]={level=275,maximum=300}}}},
    linkedInnDiscoveries={Linked={professions={[164]={rank=150,max=225}}}}}
local savedName=AF.GetProfessionName
AF.GetProfessionName=function() return "Blacksmithing" end
local function label(name,skill)
    return AF:GetForeverProfessionLabel({name=name,entry={name=name,professionID=164,skillLevel=skill}},164)
end
assert(label("Alt")=="Blacksmithing (225/300)","own alt skill comes from its profession profile")
assert(label("Remote")=="Blacksmithing (275/300)","native peer skill is displayed")
assert(label("Linked")=="Blacksmithing (150/225)","Linked Inn rank is displayed")
assert(label("Guild",190)=="Blacksmithing (190)","guild rank without maximum is displayed")
assert(label("Unknown")=="Blacksmithing","missing levels are not invented")
AF.db=savedDB AF.GetProfessionName=savedName
print("PASS profession labels include known own, remote, Linked Inn and guild skill levels")
