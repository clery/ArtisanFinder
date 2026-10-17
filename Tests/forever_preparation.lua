local AF={db={}}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
load("Features/Customer/PreparationTracker.lua") load("Features/Forever/PreparationTracker.lua")
AF.NormalizeName=function(_,name) return name end
AF.Now=function() return 1000 end
AF.GetDisplayItemName=function(_,id) return "Item "..id end
AF.Text=function(_,key,...) local value=AF.L[key] or key return select("#",...)>0 and value:format(...) or value end
AF.Print=function(self,message) self.message=message end
-- Keep native tracker unavailable to exercise persistence without any order UI.
C_CraftingOrders=nil ProfessionsCustomerOrdersFrame=nil
Enum={CraftingReagentType={Basic=1,Optional=2},ItemBind={OnAcquire=1,OnEquip=2}}
local slots={
 {required=true,quantityRequired=4,reagents={{itemID=10}}},
 {reagentType=1,quantityRequired=2,reagents={{itemID=10}}},
 {required=true,quantityRequired=3,reagents={{itemID=20}}},
 {required=true,quantityRequired=1,reagents={{itemID=30}}},
 {reagentType=2,quantityRequired=9,reagents={{itemID=99}}},
 {hiddenInCraftingForm=true,required=true,quantityRequired=9,reagents={{itemID=98}}},
}
C_TradeSkillUI={GetRecipeSchematic=function(id) assert(id==123) return {reagentSlotSchematics=slots} end}
local entry={name="Alt Crafter",recipeID=123,itemID=500,craftName="Test Craft",professionID=164}
local prepared=AF:TrackForeverCraftMaterials(entry)
assert(prepared and #prepared.reagents==3 and prepared.reagents[1].quantity==6,"required materials merge exact counts, omit optional/hidden slots")
assert(prepared.itemName=="Test Craft" and prepared.target=="Alt Crafter" and prepared.mode=="standard")
AF:TrackForeverCraftMaterials(entry)
assert(#AF.db.preparedCrafts==1,"tracking again replaces rather than duplicates the craft")
local owned={[10]=2,[20]=0,[30]=0}
C_Item={GetItemCount=function(id) return owned[id] or 0 end,
 GetItemInfo=function(id) return "Material "..id,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,id==30 and 1 or 2 end}
AuctionHouseFrame={IsShown=function() return true end}
local terms
Auctionator={API={v1={MultiSearchAdvanced=function(_,searchTerms) terms=searchTerms end}}}
assert(AF:SearchAuctionatorPreparationReagents())
assert(#terms==2 and terms[1].searchString=="Material 10" and terms[1].quantity==4 and terms[1].isExact,"Auctionator searches exact missing totals")
assert(terms[2].quantity==3 and not terms[1].tier,"no Forever quality filters; bind-on-pickup material excluded")
owned[10]=6 owned[20]=3 terms=nil
AF:SearchAuctionatorPreparationReagents()
assert(terms==nil,"nothing is searched when all auctionable materials are owned")
Auctionator=nil
assert(not AF:SearchAuctionatorPreparationReagents(),"missing Auctionator is handled")
C_TradeSkillUI.GetRecipeSchematic=function() return nil end
local fallback=AF:CreatePreparedCraftEntry({name="Crafter",recipeID=124,itemID=501,reagents={{itemID=40,quantity=5}}})
assert(fallback.reagents[1].quantity==5,"scanned/shared reagent data works without a live schematic")
local count=#AF.db.preparedCrafts
assert(not AF:TrackForeverCraftMaterials({recipeID=125,itemID=502,name="Unknown Crafter"}))
assert(#AF.db.preparedCrafts==count,"unavailable recipe data never creates an empty checklist")
-- Exercise the actual shared objective module with Forever's module interface.
local events,lines={},{}
CreateFrame=function() return {RegisterEvent=function(_,event) events[event]=true end,SetScript=function() end} end
Mixin=function(object,...)
    for index=1,select("#",...) do for key,value in pairs(select(index,...)) do object[key]=value end end
    return object
end
ObjectiveTrackerFrame={HasModule=function(self,module) return self.module==module end,MarkDirty=function() end}
ObjectiveTrackerManager={SetModuleContainer=function(_,module,container) container.module=module end}
ObjectiveTrackerContainerMixin={}
ObjectiveTrackerModuleMixin={OnLoad=function(self) self:InitModule() end,
 MarkDirty=function(self) self.dirty=(self.dirty or 0)+1 end,
 GetBlock=function(_,key) return {id=key,SetHeader=function() end,AddObjective=function(_,id,text)
    lines[#lines+1]=text
    return {Button={Show=function() end},Icon={SetShown=function() end,SetAtlas=function() end}}
 end} end,LayoutBlock=function() return true end}
AF:InitializePreparationTracker()
assert(AF:IsPreparationObjectiveTrackerInstalled() and events.BAG_UPDATE_DELAYED,"tracker installs and watches inventory after login")
local module=AF.preparationObjectiveTracker
module:AddPreparedCraftBlock(prepared,1)
assert(#lines==3,"native objective section displays only required material counts, without a summary")
local dirty=module.dirty
module:OnEvent("BAG_UPDATE_DELAYED")
assert(module.dirty==dirty+1,"bag changes refresh material completion counts")
local existing=AF.db.preparedCrafts
load("Features/Customer/PreparationTracker.lua")
AF:InitializePreparationTracker()
assert(AF.db.preparedCrafts==existing and #existing==1,"initialization restores tracking without clearing saved crafts")
AF:RemovePreparedCraft(prepared.key)
assert(#AF.db.preparedCrafts==0,"untracking removes persisted craft")
print("PASS Forever material tracking, exact quantities, persistence, untrack, missing data and shared Auctionator searches")
